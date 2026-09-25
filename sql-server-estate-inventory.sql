/*=============================================================================
  SQL Server Estate Inventory
  Forward Thinkers Consulting  |  forwardthinkersconsulting.com
  Script version 1.6

  WHAT THIS DOES
    Reads version, edition, patch level, configuration, and database inventory
    from the instance you run it against. Returns two result sets. Changes
    nothing.

  WHAT THIS DOES NOT DO
    No GRANT, INSERT, UPDATE, DELETE, CREATE, ALTER, or DROP against any object.
    No dynamic SQL. No cursors. No xp_cmdshell. No sp_configure.
    No registry reads. No file system access. No network calls.
    Does not read the contents of any user table.
    Runs under READ UNCOMMITTED so it takes no locks and blocks nothing.

  WHAT THE OUTPUT CONTAINS
    Your server name, instance name, database names, file sizes, configuration
    values, and backup dates. No row data from any user table. Review it before
    you send it anywhere.

  HOW TO RUN IT
    1. Open in SQL Server Management Studio, connected to the instance.
    2. Press Ctrl+T  (Results to Text).
    3. Press F5.
    4. Click in the results pane, Ctrl+S, save as
       <servername>_inventory.txt
    Repeat per instance.

  PERMISSIONS
    Runs best as sysadmin. Without it, the script still completes: sections you
    lack permission for report "not collected" instead of failing.

  COMPATIBILITY
    SQL Server 2008 through 2022. Uses no syntax newer than 2008.
=============================================================================*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @ScriptVersion   varchar(10);
DECLARE @ProductVersion  nvarchar(128);
DECLARE @MajorVersion    int;
DECLARE @MinorVersion    int;
DECLARE @VersionName     varchar(40);
DECLARE @ExtendedEndDate date;
DECLARE @SupportStatus   varchar(60);
DECLARE @MonthsRemaining int;
DECLARE @CanViewServerState bit;
DECLARE @Today           date;

SET @ScriptVersion  = '1.0';
SET @Today          = CONVERT(date, GETDATE());
SET @ProductVersion = CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion'));
SET @MajorVersion   = CONVERT(int, PARSENAME(@ProductVersion, 4));
SET @MinorVersion   = CONVERT(int, PARSENAME(@ProductVersion, 3));
SET @CanViewServerState = CONVERT(bit, HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE'));

SET @VersionName =
    CASE
        WHEN @MajorVersion =  8                        THEN 'SQL Server 2000'
        WHEN @MajorVersion =  9                        THEN 'SQL Server 2005'
        WHEN @MajorVersion = 10 AND @MinorVersion <  50 THEN 'SQL Server 2008'
        WHEN @MajorVersion = 10 AND @MinorVersion >= 50 THEN 'SQL Server 2008 R2'
        WHEN @MajorVersion = 11                        THEN 'SQL Server 2012'
        WHEN @MajorVersion = 12                        THEN 'SQL Server 2014'
        WHEN @MajorVersion = 13                        THEN 'SQL Server 2016'
        WHEN @MajorVersion = 14                        THEN 'SQL Server 2017'
        WHEN @MajorVersion = 15                        THEN 'SQL Server 2019'
        WHEN @MajorVersion = 16                        THEN 'SQL Server 2022'
        WHEN @MajorVersion = 17                        THEN 'SQL Server 2025'
        ELSE 'Unrecognized (' + ISNULL(@ProductVersion, 'unknown') + ')'
    END;

SET @ExtendedEndDate =
    CASE
        WHEN @MajorVersion =  8                        THEN CONVERT(date, '2013-04-09', 120)
        WHEN @MajorVersion =  9                        THEN CONVERT(date, '2016-04-12', 120)
        WHEN @MajorVersion = 10                        THEN CONVERT(date, '2019-07-09', 120)
        WHEN @MajorVersion = 11                        THEN CONVERT(date, '2022-07-12', 120)
        WHEN @MajorVersion = 12                        THEN CONVERT(date, '2024-07-09', 120)
        WHEN @MajorVersion = 13                        THEN CONVERT(date, '2026-07-14', 120)
        WHEN @MajorVersion = 14                        THEN CONVERT(date, '2027-10-12', 120)
        WHEN @MajorVersion = 15                        THEN CONVERT(date, '2030-01-08', 120)
        WHEN @MajorVersion = 16                        THEN CONVERT(date, '2033-01-11', 120)
        ELSE NULL
    END;

SET @MonthsRemaining = CASE WHEN @ExtendedEndDate IS NULL THEN NULL
                            ELSE DATEDIFF(month, @Today, @ExtendedEndDate) END;

SET @SupportStatus =
    CASE
        WHEN @ExtendedEndDate IS NULL       THEN 'Unknown - verify against the Microsoft lifecycle page'
        WHEN @ExtendedEndDate <  @Today     THEN 'OUT OF EXTENDED SUPPORT'
        WHEN @MonthsRemaining <= 24         THEN 'Approaching end of support'
        ELSE 'In extended support'
    END;


DECLARE @Instance TABLE
(
    Seq     int IDENTITY(1,1),
    Section varchar(30),
    Item    varchar(60),
    Value   nvarchar(400)
);

INSERT INTO @Instance (Section, Item, Value) VALUES
    ('Report',   'Script version',         @ScriptVersion),
    ('Report',   'Collected (local time)', CONVERT(varchar(19), GETDATE(), 120)),
    ('Report',   'Collected (UTC)',        CONVERT(varchar(19), GETUTCDATE(), 120)),
    ('Report',   'Collected by',           SUSER_SNAME()),

    ('Identity', 'Machine name',           CONVERT(nvarchar(128), SERVERPROPERTY('MachineName'))),
    ('Identity', 'Instance name',          ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('InstanceName')), 'MSSQLSERVER (default)')),
    ('Identity', 'Server name',            CONVERT(nvarchar(128), SERVERPROPERTY('ServerName'))),

    ('Version',  'Product',                @VersionName),
    ('Version',  'Product version',        @ProductVersion),
    ('Version',  'Service pack level',     ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('ProductLevel')), 'not reported')),
    ('Version',  'Cumulative update',      ISNULL(CONVERT(nvarchar(128), SERVERPROPERTY('ProductUpdateLevel')), 'not reported by this version')),
    ('Version',  'Edition',                CONVERT(nvarchar(128), SERVERPROPERTY('Edition'))),
    ('Version',  'Server collation',       CONVERT(nvarchar(128), SERVERPROPERTY('Collation'))),

    ('Support',  'Extended support ends',  ISNULL(CONVERT(varchar(10), @ExtendedEndDate, 120), 'unknown')),
    ('Support',  'Status',                 @SupportStatus),
    ('Support',  'Months remaining',       CASE WHEN @MonthsRemaining IS NULL THEN 'unknown'
                                                WHEN @MonthsRemaining < 0 THEN 'past end of support by ' + CONVERT(varchar(10), ABS(@MonthsRemaining)) + ' months'
                                                ELSE CONVERT(varchar(10), @MonthsRemaining) END),

    ('Topology', 'Clustered',              CASE CONVERT(int, SERVERPROPERTY('IsClustered')) WHEN 1 THEN 'Yes' ELSE 'No' END),
    ('Topology', 'Always On enabled',      CASE ISNULL(CONVERT(int, SERVERPROPERTY('IsHadrEnabled')), -1) WHEN 1 THEN 'Yes' WHEN 0 THEN 'No' ELSE 'not reported by this version' END),
    ('Topology', 'Full-text installed',    CASE CONVERT(int, SERVERPROPERTY('IsFullTextInstalled')) WHEN 1 THEN 'Yes' ELSE 'No' END),
    ('Topology', 'Windows auth only',      CASE CONVERT(int, SERVERPROPERTY('IsIntegratedSecurityOnly')) WHEN 1 THEN 'Yes' ELSE 'No (mixed mode)' END);

-- Configuration values (sys.configurations is readable by public)
INSERT INTO @Instance (Section, Item, Value)
SELECT 'Config', name, CONVERT(nvarchar(400), value_in_use)
FROM   sys.configurations
WHERE  name IN ('max server memory (MB)',
                'min server memory (MB)',
                'max degree of parallelism',
                'cost threshold for parallelism',
                'optimize for ad hoc workloads',
                'backup compression default',
                'clr enabled',
                'xp_cmdshell',
                'remote admin connections');

-- Host sizing and uptime (requires VIEW SERVER STATE)
IF @CanViewServerState = 1
BEGIN
    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Host', 'Logical CPUs', CONVERT(nvarchar(400), cpu_count) FROM sys.dm_os_sys_info;

    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Host', 'Schedulers', CONVERT(nvarchar(400), scheduler_count) FROM sys.dm_os_sys_info;

    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Host', 'SQL Server started', CONVERT(varchar(19), sqlserver_start_time, 120) FROM sys.dm_os_sys_info;

    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Host', 'Days up', CONVERT(nvarchar(400), DATEDIFF(day, sqlserver_start_time, GETDATE())) FROM sys.dm_os_sys_info;
END
ELSE
BEGIN
    INSERT INTO @Instance (Section, Item, Value) VALUES
        ('Host', 'CPU / uptime', 'not collected - account lacks VIEW SERVER STATE');
END

-- Linked servers
INSERT INTO @Instance (Section, Item, Value)
SELECT 'Connections', 'Linked servers', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.servers
WHERE  is_linked = 1;

-- Database counts and footprint
INSERT INTO @Instance (Section, Item, Value)
SELECT 'Databases', 'Total databases', CONVERT(nvarchar(400), COUNT(*)) FROM sys.databases;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Databases', 'User databases', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE database_id > 4;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Databases', 'Not ONLINE', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE state_desc <> 'ONLINE';

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Databases', 'Compatibility level ' + CONVERT(varchar(10), compatibility_level),
       CONVERT(nvarchar(400), COUNT(*)) + ' database(s)'
FROM   sys.databases
GROUP  BY compatibility_level;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Databases', 'Collation differs from server', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases
WHERE  collation_name IS NOT NULL
AND    collation_name <> CONVERT(nvarchar(128), SERVERPROPERTY('Collation'));

BEGIN TRY
    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Databases', 'Total data file size (GB)',
           CONVERT(nvarchar(400), CONVERT(decimal(12,1), SUM(CONVERT(bigint, size)) * 8.0 / 1048576.0))
    FROM   sys.master_files WHERE type_desc = 'ROWS';

    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Databases', 'Total log file size (GB)',
           CONVERT(nvarchar(400), CONVERT(decimal(12,1), SUM(CONVERT(bigint, size)) * 8.0 / 1048576.0))
    FROM   sys.master_files WHERE type_desc = 'LOG';
END TRY
BEGIN CATCH
    INSERT INTO @Instance (Section, Item, Value) VALUES
        ('Databases', 'File sizes', 'not collected - ' + ERROR_MESSAGE());
END CATCH

-- Feature usage that changes migration effort
INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Databases published for replication', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE is_published = 1 OR is_merge_published = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Databases subscribed to replication', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE is_subscribed = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Distribution database present', CASE WHEN COUNT(*) > 0 THEN 'Yes' ELSE 'No' END
FROM   sys.databases WHERE is_distributor = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Databases with CDC enabled', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE is_cdc_enabled = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Databases with TDE', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE is_encrypted = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'Databases with Service Broker', CONVERT(nvarchar(400), COUNT(*))
FROM   sys.databases WHERE is_broker_enabled = 1;

INSERT INTO @Instance (Section, Item, Value)
SELECT 'Features', 'SSIS catalog (SSISDB) present', CASE WHEN COUNT(*) > 0 THEN 'Yes' ELSE 'No' END
FROM   sys.databases WHERE name = 'SSISDB';

BEGIN TRY
    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Features', 'SSIS packages stored in msdb', CONVERT(nvarchar(400), COUNT(*))
    FROM   msdb.dbo.sysssispackages;
END TRY
BEGIN CATCH
    INSERT INTO @Instance (Section, Item, Value) VALUES
        ('Features', 'SSIS packages stored in msdb', 'not collected - ' + ERROR_MESSAGE());
END CATCH

BEGIN TRY
    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Agent', 'SQL Agent jobs (total)', CONVERT(nvarchar(400), COUNT(*)) FROM msdb.dbo.sysjobs;

    INSERT INTO @Instance (Section, Item, Value)
    SELECT 'Agent', 'SQL Agent jobs (enabled)', CONVERT(nvarchar(400), COUNT(*)) FROM msdb.dbo.sysjobs WHERE enabled = 1;
END TRY
BEGIN CATCH
    INSERT INTO @Instance (Section, Item, Value) VALUES
        ('Agent', 'SQL Agent jobs', 'not collected - ' + ERROR_MESSAGE());
END CATCH

SELECT Section, Item, Value
FROM   @Instance
ORDER  BY Seq;


SELECT
    d.name                                  AS DatabaseName,
    d.state_desc                            AS State,
    d.recovery_model_desc                   AS RecoveryModel,
    d.compatibility_level                   AS CompatLevel,
    CASE WHEN d.collation_name IS NULL THEN ''
         WHEN d.collation_name = CONVERT(nvarchar(128), SERVERPROPERTY('Collation')) THEN ''
         ELSE d.collation_name END          AS CollationIfDifferent,
    CONVERT(decimal(12,1), f.DataMB)        AS DataMB,
    CONVERT(decimal(12,1), f.LogMB)         AS LogMB,
    CONVERT(varchar(10), d.create_date, 120) AS Created,
    ISNULL(CONVERT(varchar(10), b.LastFullBackup, 120), 'none found') AS LastFullBackup,
    ISNULL(CONVERT(varchar(10), b.LastLogBackup, 120), '')            AS LastLogBackup,
    LTRIM(
        CASE WHEN d.is_published = 1 OR d.is_merge_published = 1 THEN ' REPL-PUB' ELSE '' END +
        CASE WHEN d.is_subscribed = 1     THEN ' REPL-SUB'  ELSE '' END +
        CASE WHEN d.is_distributor = 1    THEN ' DISTRIB'   ELSE '' END +
        CASE WHEN d.is_cdc_enabled = 1    THEN ' CDC'       ELSE '' END +
        CASE WHEN d.is_encrypted = 1      THEN ' TDE'       ELSE '' END +
        CASE WHEN d.is_broker_enabled = 1 THEN ' BROKER'    ELSE '' END +
        CASE WHEN d.is_read_only = 1      THEN ' READONLY'  ELSE '' END +
        CASE WHEN d.is_auto_close_on = 1  THEN ' AUTOCLOSE' ELSE '' END +
        CASE WHEN d.is_auto_shrink_on = 1 THEN ' AUTOSHRINK' ELSE '' END +
        CASE WHEN d.page_verify_option_desc <> 'CHECKSUM' THEN ' PAGEVERIFY-' + d.page_verify_option_desc ELSE '' END
    )                                       AS Flags
FROM sys.databases AS d
LEFT JOIN
(
    SELECT database_id,
           SUM(CASE WHEN type_desc = 'ROWS' THEN CONVERT(bigint, size) ELSE 0 END) * 8.0 / 1024.0 AS DataMB,
           SUM(CASE WHEN type_desc = 'LOG'  THEN CONVERT(bigint, size) ELSE 0 END) * 8.0 / 1024.0 AS LogMB
    FROM   sys.master_files
    GROUP  BY database_id
) AS f ON f.database_id = d.database_id
LEFT JOIN
(
    SELECT database_name,
           MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup,
           MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup
    FROM   msdb.dbo.backupset
    GROUP  BY database_name
) AS b ON b.database_name = d.name
ORDER BY
    CASE WHEN d.database_id <= 4 THEN 0 ELSE 1 END,
    d.name;
