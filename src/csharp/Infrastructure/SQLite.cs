using System;
using System.IO;
using Godot;
using Microsoft.Data.Sqlite;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class SQLite : RefCounted
{
    public string path { get; set; } = "user://save/harmonia.db";
    public bool read_only { get; set; } = false;

    private SqliteConnection _connection;
    private string _lastError = string.Empty;
    private GArray _queryResult = new GArray();

    public bool open_db()
    {
        return OpenInternal(path);
    }

    public bool open_database(string dbPath)
    {
        return OpenInternal(dbPath);
    }

    public bool query_with_bindings(string sql, GArray bindings)
    {
        return query(sql, bindings);
    }

    public bool query(string sql)
    {
        return query(sql, new GArray());
    }

    public bool query(string sql, GArray bindings)
    {
        _queryResult = new GArray();
        _lastError = string.Empty;

        if (_connection == null && !OpenInternal(path))
        {
            return false;
        }

        if (_connection == null)
        {
            _lastError = "SQLite connection is not initialized.";
            return false;
        }

        try
        {
            using var command = _connection.CreateCommand();
            command.CommandText = sql;
            BindParameters(command, bindings);

            var firstToken = FirstToken(sql);
            if (IsReaderQuery(firstToken))
            {
                using var reader = command.ExecuteReader();
                while (reader.Read())
                {
                    var row = new GDictionary();
                    for (var i = 0; i < reader.FieldCount; i++)
                    {
                        var name = reader.GetName(i);
                        row[name] = ToGodotValue(reader.GetValue(i));
                    }
                    _queryResult.Add(row);
                }
            }
            else
            {
                command.ExecuteNonQuery();
            }

            return true;
        }
        catch (Exception ex)
        {
            _lastError = ex.Message;
            GD.PrintErr($"SQLite bridge query failed: {_lastError}");
            return false;
        }
    }

    public GArray get_query_result()
    {
        return _queryResult;
    }

    public string get_error_message()
    {
        return _lastError;
    }

    private bool OpenInternal(string dbPath)
    {
        try
        {
            var resolvedPath = ResolvePath(dbPath);
            EnsureParentDirectory(resolvedPath);

            var connectionStringBuilder = new SqliteConnectionStringBuilder
            {
                DataSource = resolvedPath,
                Mode = read_only ? SqliteOpenMode.ReadOnly : SqliteOpenMode.ReadWriteCreate,
                Cache = SqliteCacheMode.Default
            };

            _connection?.Dispose();
            _connection = new SqliteConnection(connectionStringBuilder.ConnectionString);
            _connection.Open();
            path = dbPath;
            return true;
        }
        catch (Exception ex)
        {
            _lastError = ex.Message;
            GD.PrintErr($"SQLite bridge open failed: {_lastError}");
            _connection?.Dispose();
            _connection = null;
            return false;
        }
    }

    private static string ResolvePath(string dbPath)
    {
        if (string.IsNullOrWhiteSpace(dbPath))
        {
            return ProjectSettings.GlobalizePath("user://save/harmonia.db");
        }

        if (dbPath.StartsWith("user://", StringComparison.Ordinal) || dbPath.StartsWith("res://", StringComparison.Ordinal))
        {
            return ProjectSettings.GlobalizePath(dbPath);
        }

        return dbPath;
    }

    private static void EnsureParentDirectory(string fullPath)
    {
        var parent = Path.GetDirectoryName(fullPath);
        if (!string.IsNullOrWhiteSpace(parent))
        {
            Directory.CreateDirectory(parent);
        }
    }

    private static void BindParameters(SqliteCommand command, GArray bindings)
    {
        // Current GDScript adapter path passes an empty bindings list.
        // Keep this method for API compatibility and future parameterization.
        _ = command;
        _ = bindings;
    }

    private static string FirstToken(string sql)
    {
        if (string.IsNullOrWhiteSpace(sql))
        {
            return string.Empty;
        }

        var trimmed = sql.TrimStart();
        var firstSpace = trimmed.IndexOfAny(new[] { ' ', '\n', '\r', '\t' });
        if (firstSpace <= 0)
        {
            return trimmed.ToUpperInvariant();
        }

        return trimmed.Substring(0, firstSpace).ToUpperInvariant();
    }

    private static bool IsReaderQuery(string firstToken)
    {
        return firstToken == "SELECT" || firstToken == "PRAGMA" || firstToken == "WITH";
    }

    private static Variant ToGodotValue(object value)
    {
        if (value == null || value is DBNull)
        {
            return Variant.CreateFrom(string.Empty);
        }

        return value switch
        {
            long l => Variant.CreateFrom(l),
            int i => Variant.CreateFrom(i),
            short s => Variant.CreateFrom((int)s),
            byte b => Variant.CreateFrom((int)b),
            bool bo => Variant.CreateFrom(bo),
            float f => Variant.CreateFrom(f),
            double d => Variant.CreateFrom(d),
            decimal m => Variant.CreateFrom((double)m),
            string str => Variant.CreateFrom(str),
            byte[] bytes => Variant.CreateFrom(Convert.ToBase64String(bytes)),
            _ => Variant.CreateFrom(value.ToString() ?? string.Empty)
        };
    }
}
