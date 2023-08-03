YDBSyslog – Capture Syslog data in a Database for Analytics, Troubleshooting and Forensics

YDBSyslog is a tool to capture syslog data in a YottaDB database using the `journalctl --output=export` format. It operates in two modes:

- Running `journalctl` in a PIPE device. With the optional `--follow` option, YDBSyslog continuously monitors `journalctl` output and captures the output in real time.
- Reading a `journalctl` export from stdin. Reading from `journalctl --output=export --follow` in a pipe is effectively the same as reading from a PIPE device with the `--follow` option.

YDBSyslog can output a DDL which can be fed to Octo, allow the syslog to be queried using SQL.

## Usage

```
yottadb -run %YDBSYSLOG op [options]
```

Op [options] are

- `help` - Output options to use this program.
- `ingestjnlctlcmd [options]` - Run the `journalctl --output=export` command in a PIPE.
  Options are as follows; all options may be omitted.
  `--boot [value]` - `--boot` is mutually exclusive with `--follow`. There are several cases:
    1. If `value` is omitted, the `--boot` parameter is omitted when invoking `journalctl`.
    1. If `value` is a hex string prefixed with `0x`, the string sans prefix is passed to `journalctl --boot`.
    1. If a decimal number, it is passed unaltered to `journalctl --boot`.
    1. If a case-independent `all`, that option is passed to `journalctl --boot`.
  `--follow` is mutually exclusive with `--boot`. The `--follow` option is used to invoke `journalctl --follow`, and results in a continuous capture in the database of the syslog exported by `journalctl`.
  `--moreopt` indicates that the rest of the command line should be passed verbatim to the `journalctl` command as additional options. See the Linux command `man journalctl` for details. YDBSyslog does no error checking of these additional options.
- `ingestjnlctlfile` – read `journalctl --output=export` formatted data from stdin.
- `octoddl` - output an Octo DDL to allow analysis of syslog data using SQL. Note that if the database combines syslog data from multiple systems, Octo SQL queries can span systems.

The following M entryrefs can called directly from applications written in M and other programming languages that support calls to M.

- `INGESTJNLCTLCMD^%YDBSYSLOG(boot,follow,moreopt)` runs `journalctl --output=export` in a PIPE device. Parameters are:
  - `boot` is the parameter for the `--boot` command line option of `journalctl`. There are several cases:
    1. If unspecified or the empty string, the `--boot` option is omitted.
    1. If a hex string prefixed with `"0x"`, the string sans prefix is passed to `journalctl` as the value.
    1. If a decimal number, it is passed unaltered to `journalctl`.
    1. If a case-independent `"all"`, that option is passed to `journalctl`.
  - If `follow` is non-zero, INGESTJNLCTLCMD follows journalctl, continuously logging syslog output in the database. `boot` and `follow` are mutuially exclusive.
  - `moreopt` is a string intended to be passed verbatim to the journalctl command. See the Linux command `man journalctl` for details. INGESTJNLCTMCMD does no error checking of these additional options.
- `INGESTJNLCTLFILE^%YDBSYSLOG` reads `jnlctl --output=export` formatted data from stdin.
- `OCTODDL^%YDBSYSLOG` generates the DDL that can be fed to Octo to query the ingested syslog data using SQL.

Data are stored in nodes of `^%ydbSYSLOG` with the following subscripts, which are reverse engineered from the `__CURSOR` field of the `journalctl` export format. While `__CURSOR` is designated as opaque, reverse engineering provides a more compact database and faster access:

- `Cs` – a UUID for a large number of syslog records.
- `Cb` – evidently a boot UUID.
- `Ci` - evidently the record number in a syslog.
- `Ct` - evidently the number of microseconds since the UNIX epoch.
- `Cm` – evidently a monolithic timestamp since boot.
- `Cx` - a UUID that is unique to each syslog entry.

Fields that `journalctl` has been found to flag as binary, e.g., `"MESSAGE"` and `"SYSLOG_RAW"` have an additional, sixth, subscript, the tag for the field.

Note that since querying syslog entries is content based (e.g., the USER_ID field) and not by the subscripts, if the reverse engineering of `__CURSOR` is imperfect, or if a future `systemd-journald` changes the fields, it will not affect the correctness of queries; it will only affect database size and consequently access speed (smaller databases are faster).

The numerous fields exported by `journalctl` are not well documented. [Systemd Journal Export Formats](https://systemd.io/JOURNAL_EXPORT_FORMATS/) is helpful, as is [man systemd.journal-fields](https://www.freedesktop.org/software/systemd/man/systemd.journal-fields.html). However, outside the source code, there does not appear to be a comprehensive list of all fields. The fields listed in the `_YDBSYSLOG.m` source code were captured from a couple dozen Linux systems running releases and derivatives of Arch Linux, Debian GNU/Linux, Red Hat Enterprise Linux, SUSE Linux Enterprise, and Ubuntu. Even if `journalctl` exports additional fields not identified, %YDBSYSLOG captures them, and generates reasonable DDL entries for them.

Should you find additional entries not identified by the `_YDBSYSLOG.m` source code, please create an Issue or a Merge Request.

### Sample Script

Although there are many ways to script gathering data using %YDBSYSLOG, the program UseYDBSyslog is a sample script you can use. After reading the comments in the file `UseYDBSyslog.txt`:

1. Edit the file `UseYDBSyslog.txt` to replace the sample loghost name, server names, and starting TCP port with the specific values for your environment.
1. Save the file as `UseYDBSyslog.m` on the loghost and on each server in a location where YottaDB can execute it.
1. To use it, first start it on the loghost, and then on each server, and confirm that the two port numbers reported by the loghost for each server match those the server reports.
1. To collect all syslogs from all servers, intially, start it with `yottadb -run %XCMD 'do ^UseYDBSyslog(1)'`. Subsequently, a simple `yottadb -run UseYDBSyslog` suffices to capture syslogs from the current boot.

The default configuration of UseYDBSyslog creates an unjournaled database that uses the MM access method. If you use journaling for recoverability, remember to monitor space used by prior generation journal files, and to delete those old journal files when they are no longer needed.

## Installation

Since this is a plug-in for [YottaDB](https://gitlab.com/YottaDB/DB/YDB),
YottaDB must be installed first.

YDBSyslog requires YottaDB r1.36 or higher.

To install, you need `cmake`, `make`, `cc`, and `ld` commands. After
downloading this repository, you can install as follows:

```
cd <project directory>
mkdir build && cd build
cmake .. && make && sudo make install
```

Here is a sample installation:

```
$ cmake ..
-- YDBCMake Source Directory: /home/ydbuser/work/gitlab/YDBSyslog/build/_deps/ydbcmake-src
-- Setting locale to C.UTF-8
-- Found YOTTADB: /usr/local/lib/yottadb/r138/libyottadb.so
-- Install Location: /usr/local/lib/yottadb/r138/plugin
-- Configuring done (1.0s)
-- Generating done (0.0s)
-- Build files have been written to: /home/ydbuser/work/gitlab/YDBSyslog/build
$ make
[ 25%] Building M object CMakeFiles/_ydbsyslogM.dir/_YDBSYSLOG.m.o
[ 50%] Linking M shared library _ydbsyslog.so
[ 50%] Built target _ydbsyslogM
[ 75%] Building M object CMakeFiles/_ydbsyslogutf8.dir/_YDBSYSLOG.m.o
[100%] Linking M shared library utf8/_ydbsyslog.so
[100%] Built target _ydbsyslogutf8
$ sudo make install
[ 50%] Built target _ydbsyslogM
[100%] Built target _ydbsyslogutf8
Install the project...
-- Install configuration: ""
-- Installing: /usr/local/lib/yottadb/r138/plugin/o/_ydbsyslog.so
-- Installing: /usr/local/lib/yottadb/r138/plugin/o/utf8/_ydbsyslog.so
-- Up-to-date: /usr/local/lib/yottadb/r138/plugin/r/_YDBSYSLOG.m
$ 
```

## Example

```
$ yottadb -run %YDBSYSLOG ingestjnlctlcmd --boot all # Get syslogs from mylaptop
$ yottadb -run %YDBSYSLOG ingestjnlctlfile </extra/tmp/journalctl.export # Get exported journalctl from my server
$ yottadb -run %YDBSYSLOG octoddl | octo # Define TABLE in Octo
DROP TABLE
CREATE TABLE
$ echo "select _HOSTNAME, _COMM, MESSAGE from SYSLOG_DATA where _UID = 2261 and ( _COMM = 'mupip' or _COMM = 'yottadb' or _COMM = 'mumps' ) limit 2;" | octo
_HOSTNAME|_COMM|MESSAGE
mylaptop|mupip|%YDB-I-FILERENAME, File /tmp/test/r1.38_x86_64/g/yottadb.mjl is renamed to /tmp/test/r1.38_x86_64/g/yottadb.mjl_2023180120821 -- generated from 0x00007F5CDDC4B36E.
mylaptop|mupip|%YDB-I-FILERENAME, File /tmp/test/r1.38_x86_64/g/%ydbocto.mjl is renamed to /tmp/test/r1.38_x86_64/g/%ydbocto.mjl_2023180120821 -- generated from 0x00007F5CDDC4B36E.
(2 rows)
$ echo "select _HOSTNAME, _COMM, MESSAGE from SYSLOG_DATA where _UID = 4528 and ( _COMM = 'mupip' or _COMM = 'yottadb' or _COMM = 'mumps' ) limit 2;" | octo
_HOSTNAME|_COMM|MESSAGE
myserver|mumps|%YDB-I-TEXT, %YDB-E-ZGBLDIRACC, Cannot access global directory /extra1/testarea1/testsys/tst_V989_R139_dbg_17_230707_173250/sudo_0/gtm7759/mumps.gld.  Cannot continue. -- generated from 0x00007FCCF1244143.
myserver|mumps|%YDB-I-TEXT, %YDB-E-DBPRIVERR, No privilege for attempted update operation for file: /extra1/testarea1/testsys/tst_V989_R139_dbg_17_230707_173250/sudo_0/gtm7759/mumps.dat -- generated from 0x00007FEE9C112143.
(2 rows)
$ 
```

# License

See both the COPYING and LICENSE files.
