# SQL Server Estate Inventory

A single read-only T-SQL script that tells you what SQL Server versions you are actually running, whether they are still supported, and what is in each database.

Run it once per instance. It changes nothing.

## Why this exists

SQL Server 2016 left extended support on July 14, 2026. SQL Server 2017 follows on October 12, 2027.

Most organizations we talk to are not certain which of their instances are affected, because the estate grew over a decade and the inventory lives in several places that do not agree with each other. Before anyone can budget for a migration, somebody has to produce a defensible list.

This script produces that list.

## What it collects

**Instance summary**

- Machine name, instance name, server name
- Product version, edition, service pack, cumulative update
- Extended support end date and whether you are past it
- Server collation, clustering, Always On, authentication mode
- Selected configuration values (max and min server memory, MAXDOP, cost threshold, backup compression, CLR, xp_cmdshell)
- CPU count, scheduler count, uptime
- Linked server count, SQL Agent job count
- Replication, CDC, TDE, Service Broker, and SSIS usage across the instance
- Database count and total data and log footprint

**Per database**

- Name, state, recovery model, compatibility level
- Collation, but only when it differs from the server
- Data and log size
- Creation date, last full backup, last log backup
- Flags for replication, CDC, TDE, Service Broker, read-only, auto-close, auto-shrink, and non-CHECKSUM page verification

## What it does not do

- No INSERT, UPDATE, DELETE, CREATE, ALTER, or DROP against any object
- No dynamic SQL
- No cursors
- No xp_cmdshell
- No sp_configure or RECONFIGURE
- No registry reads, no file system access, no network calls
- Does not read the contents of any user table
- Runs under READ UNCOMMITTED, so it takes no locks and blocks nothing

The script is about 300 lines including comments. Read it before you run it. That is the point of publishing it this way instead of emailing you a file.

## How to run it

1. Open `sql-server-estate-inventory.sql` in SQL Server Management Studio, connected to the instance you want to inventory.
2. Press **Ctrl+T** to switch to Results to Text.
3. Press **F5**.
4. Click in the results pane, press **Ctrl+S**, and save as `<servername>_inventory.txt`.

Repeat for each instance. There is no configuration to change and nothing to install.

## Permissions

It runs best as a member of `sysadmin`.

Without that, it still completes. The script checks for `VIEW SERVER STATE` before touching any dynamic management view, and wraps the `msdb` and `sys.master_files` reads in error handling. Sections you lack permission for report `not collected` and the rest of the report is unaffected.

## Compatibility

SQL Server 2008 through 2022. The script deliberately avoids any syntax newer than 2008, because the instances most worth finding are usually the oldest ones.

It will not run on SQL Server 2005 or earlier.

## What this is not

This is not a health check. If you want to know whether your indexes are a mess, whether your wait stats are telling you something, or whether your maintenance is configured correctly, Brent Ozar's `sp_Blitz` and Ola Hallengren's maintenance solution are both free, both excellent, and both better at that than anything here.

This script answers a different question. It is an estate inventory written for the conversation where somebody has to justify a number in next year's budget. It tells you what you are running, whether it is supported, and what would be involved in moving it. That output is meant to be readable by a Director who is not a DBA.

## Sending us the output

Optional, and nothing is owed if you do.

If you send us the `.txt` file, we will read it and get on a call to walk through what it shows. No charge. For a fair number of organizations that call is the whole engagement, because the answer turns out to be simpler than they expected.

Email it to **contact@forwardthinkersconsulting.com**

**Redact whatever you want first.** Server names and database names are in the output, and at some organizations that alone is enough to make sending it a problem. We do not need them. Support status, patch level, configuration, feature usage, and backup gaps are what matter, and none of that is sensitive. Black out the names and send the rest.

## License

MIT. Provided as is, without warranty of any kind. Read the script, decide for yourself, and run it on something non-production first if that is your policy.

## Who wrote this

[Forward Thinkers Consulting](https://www.forwardthinkersconsulting.com), a data engineering practice working in SQL Server, SSIS and ETL, healthcare EDI X12, and Azure since 2010.

More on the assessment this script feeds: [SQL Server Estate Assessment](https://www.forwardthinkersconsulting.com/sql-server-assessment)
