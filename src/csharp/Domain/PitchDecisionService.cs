using System;
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class PitchDecisionService : Node
{
	private const float YinThreshold = 0.10f;
	private const float MinEnergyEpsilon = 0.0000001f;

	public Dictionary AnalyzeSamples(
		Godot.Collections.Array stereoFrames,
		float sampleRate,
		float minFrequency,
		float maxFrequency,
		float minConfidence)
	{
		if (stereoFrames.Count < 512 || sampleRate <= 0.0f)
		{
			return InvalidResult("Insufficient samples", -80.0f);
		}

		var mono = new float[stereoFrames.Count];
		var sumSquares = 0.0f;
		for (var i = 0; i < stereoFrames.Count; i++)
		{
			var frame = (Vector2)stereoFrames[i];
			var sample = (frame.X + frame.Y) * 0.5f;
			mono[i] = sample;
			sumSquares += sample * sample;
		}

		var rms = Mathf.Sqrt(sumSquares / Math.Max(stereoFrames.Count, 1));
		var inputLevelDb = Mathf.LinearToDb(Mathf.Max(rms, MinEnergyEpsilon));

		var tauMin = Math.Max((int)Math.Floor(sampleRate / Math.Max(maxFrequency, 1.0f)), 2);
		var tauMax = Math.Min((int)Math.Floor(sampleRate / Math.Max(minFrequency, 1.0f)), mono.Length / 2 - 1);
		if (tauMin >= tauMax)
		{
			return InvalidResult("YIN bounds invalid", inputLevelDb);
		}

		var cmndf = BuildCmndf(mono, tauMin, tauMax);
		var tauEstimate = SelectTau(cmndf, tauMin, tauMax);
		if (tauEstimate <= 0)
		{
			return InvalidResult("YIN tau not found", inputLevelDb);
		}

		var refinedTau = ParabolicInterpolateTau(cmndf, tauEstimate);
		if (refinedTau <= 0.0f)
		{
			return InvalidResult("YIN interpolation failed", inputLevelDb);
		}

		var frequency = sampleRate / refinedTau;
		if (frequency < minFrequency || frequency > maxFrequency)
		{
			return InvalidResult("Frequency out of range", inputLevelDb);
		}

		var confidence = 1.0f - Mathf.Clamp(cmndf[tauEstimate], 0.0f, 1.0f);
		if (confidence < minConfidence)
		{
			return InvalidResult("Confidence below threshold", inputLevelDb);
		}

		return new Dictionary
		{
			{ "valid", true },
			{ "frequency", frequency },
			{ "confidence", confidence },
			{ "input_level_db", inputLevelDb },
			{ "status", "Capturing" }
		};
	}

	private static float[] BuildCmndf(float[] mono, int tauMin, int tauMax)
	{
		var diff = new float[tauMax + 1];
		for (var tau = tauMin; tau <= tauMax; tau++)
		{
			var sum = 0.0f;
			var limit = mono.Length - tau;
			for (var i = 0; i < limit; i++)
			{
				var delta = mono[i] - mono[i + tau];
				sum += delta * delta;
			}

			diff[tau] = sum;
		}

		var cmndf = new float[tauMax + 1];
		cmndf[tauMin] = 1.0f;
		var runningSum = 0.0f;
		for (var tau = tauMin + 1; tau <= tauMax; tau++)
		{
			runningSum += diff[tau];
			cmndf[tau] = runningSum <= MinEnergyEpsilon ? 1.0f : diff[tau] * (tau - tauMin) / runningSum;
		}

		return cmndf;
	}

	private static int SelectTau(float[] cmndf, int tauMin, int tauMax)
	{
		for (var tau = tauMin + 1; tau <= tauMax; tau++)
		{
			if (cmndf[tau] < YinThreshold)
			{
				var bestTau = tau;
				while (bestTau + 1 <= tauMax && cmndf[bestTau + 1] < cmndf[bestTau])
				{
					bestTau++;
				}

				return bestTau;
			}
		}

		var minTau = -1;
		var minValue = float.MaxValue;
		for (var tau = tauMin + 1; tau <= tauMax; tau++)
		{
			if (cmndf[tau] < minValue)
			{
				minValue = cmndf[tau];
				minTau = tau;
			}
		}

		return minTau;
	}

	private static float ParabolicInterpolateTau(float[] cmndf, int tau)
	{
		var left = Math.Max(tau - 1, 0);
		var right = Math.Min(tau + 1, cmndf.Length - 1);
		if (left == tau || right == tau)
		{
			return tau;
		}

		var s0 = cmndf[left];
		var s1 = cmndf[tau];
		var s2 = cmndf[right];
		var denom = 2.0f * (2.0f * s1 - s2 - s0);
		if (Mathf.Abs(denom) < MinEnergyEpsilon)
		{
			return tau;
		}

		var delta = (s2 - s0) / denom;
		return tau + delta;
	}

	private static Dictionary InvalidResult(string status, float inputLevelDb)
	{
		return new Dictionary
		{
			{ "valid", false },
			{ "frequency", 0.0f },
			{ "confidence", 0.0f },
			{ "input_level_db", inputLevelDb },
			{ "status", status }
		};
	}
}
