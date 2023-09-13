;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;								;
; Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	;
; All rights reserved.						;
;								;
;	This source code contains the intellectual property	;
;	of its copyright holder(s), and is made available	;
;	under a license.  If you do not know the terms of	;
;	the license, please stop and do not read further.	;
;								;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
%YDBSYSLOG
	; Capture syslog data for analysis by YottaDB and Octo
	; Usage: yottadb -run $text(+0) op [options] where options are:
	; - help - Output options to use this program.
	; - ingestjnlctlcmd [options] - Run the journalctl --output=export command in a PIPE.
	;   Options are as follows; all options may be omitted.
	;   --boot [value] - --boot is mutually exclusive with --follow. There are several cases:
	;     1. If the value is omitted, the --boot parameter is omitted when invoking journalctl.
	;     2. If a hex string prefixed with "0x", the string sans prefix is passed to journalctl --boot.
	;     3. If a decimal number, it is passed unaltered to journalctl --boot.
	;     4. If a case-independent "all", that option is passed to journalctl --boot.
	;   --follow is mutually exclusive with --boot. The --follow option is used when
	;     invoking journalctl, and results in a continuous capture in the database of
	;     the syslog exported by journalctl.
	;   --moreopt indicates that the rest of the command line should be passed verbatim
	;     to the journalctl command. See the Linux command man journalctl for details.
	;     $text(+0) does no error checking of these additional options.
	; - ingestjnlctlfile - read journalctl --output=export formatted data from stdin.
	; - octoddl - output an Octo DDL to allow analysis of syslog data using SQL.
	;   --scan Scan the database for additional binary fields not already known to %YDBSYSLOG.
	;     Note that scanning a large database can take tens of seconds to minutes, especially
	;     if the database combines syslog data from multiple systems.
	; The ingestjnlctlcmd and ingestjnlctlfile commands create a YDBSLOG database region, if
	; one does not already exist, and map ^%ydbSLOG* global variables (with all combinations
	; of capitalization of SLOG) to that region.

	; terminate on Ctrl-C if invoked from the shell
	use $principal:(ctrap=$char(3):nocenable)
	new $etrap,bootopt,cmdline,func,io,moreopt,opt,scanopt
	set io=$io
	; define error trap to print error message and terminate
	; and just terminate returning status to shell if an error is encountered
	; when executing the error trap
        set $etrap="set $etrap=""use $principal write $zstatus,! zhalt 1"" do err^"_$text(+0)_" quit"
	; raise error if top level entry is from anywhere except the shell
        set:$stack $ecode=",U255,"
	set (bootopt,moreopt,opt)=""
	set cmdline=$select($length($zcmdline):$zcmdline,1:"help")
	for  quit:'$length(cmdline)  do
	. if $$trimleadingstr^%XCMD(.cmdline,"help") do help quit
	. else  if $$trimleadingstr^%XCMD(.cmdline,"ingestjnlctlcmd") do
	. . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="ingestjnlctlcmd"_cmdline,$ecode=",U249,"
	. . for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do
	. . . if $$trimleadingstr^%XCMD(.cmdline,"boot") do
	. . . . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="boot"_cmdline,$ecode=",U249,"
	. . . . set:"follow"=$get(opt) $ecode=",U248,"
	. . . . set opt="boot"
	. . . . if "--"'=$zextract(cmdline,1,2) set bootopt=$zpiece(cmdline," ",1),cmdline=$zpiece(cmdline," ",2,$zlength(cmdline," "))
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"follow") do
	. . . . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="follow"_cmdline,$ecode=",U249,"
	. . . . set:"boot"=$get(opt) $ecode=",U248,"
	. . . . set opt="follow"
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"moreopt") do
	. . . . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="moreopt"_cmdline,$ecode=",U249,"
	. . . . set moreopt=cmdline,cmdline=""
	. . do INGESTJNLCTLCMD($select("boot"=opt:$get(bootopt),1:""),$select("follow"=opt:1,1:0),$select($zlength(moreopt):" "_moreopt,1:""))
	. else  if $$trimleadingstr^%XCMD(.cmdline,"ingestjnlctlfile") do
	. . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="ingestjnlctlfile"_cmdline,$ecode=",U249,"
	. . do INGESTJNLCTLFILE
	. else  if $$trimleadingstr^%XCMD(.cmdline,"octoddl") do
	. . set:$zlength(cmdline)&'$$trimleadingstr^%XCMD(.cmdline," ") cmdline="octoddl"_cmdline,$ecode=",U249,"
	. . set scanopt=0
	. . for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do
	. . . if $$trimleadingstr^%XCMD(.cmdline,"scan") set scanopt=1
	. . . else  set cmdline="--"_cmdline,$ecode=",U249,"
	. . do OCTODDL(scanopt)
	. else  set $ecode=",U249,"
        . do trimleadingstr^%XCMD(.cmdline," ")
	quit

; Set error trap. The first action the error trap does is set a failsafe error
; trap (e.g., if $zroutines is not correct). Thereafter, it jumps to the actual
; error trap to print an error message and terminate, with a return code.
;
; Note that all external entry points:
; - NEW $ETRAP and DO etrap if $ETRAP is the default error handler. This allows
;   them to report the error messages for %YDBSYSLOG errors, instead of just
;   reporting that $ECODE was assigned a non-empty value, which the default
;   error trap will report. If an application sets an error trap ($ETRAP or
;   $ZTRAP) that will be used.
etrap
	set $etrap="set $etrap=""open """"/proc/self/fd/2"""" use """"/proc/self/fd/2"""" write $zstatus,! zhalt $piece($zstatus,"""","""",1)""  goto err^"_$text(+0)
	quit

err	; Error handler when called from another program
	; ------------------------------------------------------------------------
	; This is where control reaches when any error is encountered inside
	; %YDBSYSLOG. The code does %YDBSYSLOG-specific cleanup here and then
	; switches $etrap to a non-%YDBSYSLOG default handler that rethrows the
	; error one caller frame at a time until it unwinds to a non-%YDBSYSLOG
	; caller frame that has $etrap set at which point it can handle the
	; error accordingly.
	; ------------------------------------------------------------------------
	new errcode,errtxt,retcode,top
        set errcode=$piece($ecode,",",2),errtxt=$text(@errcode),retcode=+$extract(errcode,2,$length(errcode))
	; Restore IO device
	use io close "jnlctl"		; Close is no-op for top level invocation
	; Check for %YDBSYSLOG-specific errors (in that case "errtxt" will be non-empty).
	do:$zlength(errtxt)
	. new xstr
	. ; This is an %YDBSYSLOG specific error. Extract error text with unfilled
	. ; parameter values. "xecute" that string to fill it with actual values.
	. set xstr="set errtxt="_$zpiece(errtxt,";",2,$zlength(errtxt,";")) xecute xstr
	. set $zstatus=retcode_","_$text(+0)_errtxt
	; Now that primary error handling is done, switch to different handler
	; to rethrow the error in caller frames. The rethrow will cause a
	; different $etrap to be invoked in the first non-%YDBSYSLOG caller frame
	; (because <entryref>^%YDBSYSLOG did a "new $etrap" at entry).
	zshow "s":top
	do:$text(+0)=$zpiece(top("S",$order(top("S",""),-1)),"+",1)
	. set $ecode=""
        . if $length(errtxt) write $text(+0),errtxt,!
	. do help
	. zhalt retcode
	quit:$quit retcode quit

; Run journalctl in a PIPE and read the data
; - boot is the parameter for the --boot parameter of journalctl. There are four cases:
;   - If unspecified or the empty string, the --boot option is omitted.
;   - If a hex string prefixed with "0x", the string sans prefix is passed to journalctl.
;   - If a decimal number, it is passed unaltered to journalctl.
;   - If a case-independent "all", that option is passed to journalctl.
; - If follow is non-zero, INGESTJNLCTLCMD follows journalctl, continuously logging syslog
;   output in the database. boot and follow are mutually exclusive.
; - moreopt is a string intended to be passed verbatim to the journalctl command. See the
;   Linux command `man journalctl` for details. INGESTJNLCTMCMD does no error checking of
;   these additional options.
INGESTJNLCTLCMD(boot,follow,moreopt)
	new $etrap,bootopt,devs,followopt,i,io,jnlctlcmd,line
	set io=$io
	do etrap
	use:'$stack $principal:(ctrap=$char(3):nocenable)
	do ensurereg
	set boot=$get(boot)
	set followopt=""
	if +$get(follow) do			; Process is to run as a daemon
	. set:$zlength(boot) $ecode=",U248,"
	. set followopt=" --follow"
	. ; When INGESTJNLCTL runs as a daemon, and if one of its devices is a TERMINAL,
	. ; it should have NOCENABLE set so that a Ctrl-C terminates the daemon,
	. ; instead of putting the process into direct mode.
	. zshow "d":devs
	. for i=1:1 quit:'$data(devs("D",i))  use:$zfind(devs("D",i)," TERMINAL ") $zpiece(devs("D",i)," ",1):NOCENABLE
	. use io
	set bootopt=$select('$zlength(boot):"",$char(0)]]boot:$fnumber(boot,"+"),$$ishex(boot):$zextract(boot,3,$zlength(boot)),"all"=$zconvert(boot,"l"):"all",1:"ERR")
	set:"ERR"=bootopt $ecode=",U254,"
	set:$zlength(bootopt) bootopt=" --boot "_bootopt
	set jnlctlcmd="journalctl --no-pager --output=export"_bootopt_followopt_$select($zlength($get(moreopt)):" "_moreopt,1:"")
	open "jnlctl":(shell="/bin/sh":command=jnlctlcmd:readonly:chset="M":stderr="jnlctlerr":variable:nowrap)::"pipe"
	; Since arbitrary strings can be specified with moreopt, see whether journalctl issues an error,
	; and terminate if that is the case. As there will be nothing to read if there is no error, a wait
	; is required. The amount of the wait is intended to be long enough for slow systems, and not
	; burdensome for fast systems, since the journalctl command itself will take time to execute.
	use "jnlctlerr"
	read line:.1
	set:$test $ecode=",U252,"
	; As it appears that sometimes the count of a binary record includes the terminating linefeed, and sometimes it
	; does not, the code for reading a binary field may sometimes read the following record. Therefore, line
	; is read only if it is not the empty string, and cleared appropriately so that it is not empty only
	; when data has already been read.
	use "jnlctl"
	do proclines				; read and process lines from journalcl command
	use io close "jnlctl"
	quit

; Read jnlctl --output=export from stdin
INGESTJNLCTLFILE
	new $etrap,io
	set io=$io
	do etrap
	use:'$stack $principal:(ctrap=$char(3):nocenable)
	do ensurereg
	use $io:chset="M"
	do proclines
	quit

; Generate Octo DDL
OCTODDL(scanflag)
	new $etrap,binflds,comments,fcomment,fname,fbynum,ftype,i,io,j,keyflds,lastfnum,line,nkeyflds,tagcnt,tmp,types
	set io=$io
	do etrap
	use:'$stack $principal:(ctrap=$char(3):nocenable)
	for i=1:1 set tmp=$text(binflds+i) quit:" "=tmp  set binflds(i)="`"_$zpiece(tmp,";",2)_"`"	; Read binary fields
	for i=1:1 set line=$text(keyflds+i) quit:" "=line  do	; Read key fields (reverse engineered __CURSOR)
	. set keyflds(i)="`"_$zpiece(line,";",2)_"`;"_$zpiece(line,";",3,$zlength(line,";"))
	set nkeyflds=i-1
	do rdflds(,.types,.comments,.fbynum)			; Set piece numbers & data types for ^%ydbSLOG
	set lastfnum=$order(fbynum(""),-1)
	for i=1:1:lastfnum do
	. set fname(i)="`"_fbynum(i)_"`"
	. set ftype(i)=" "_$select($data(types(i)):types(i),1:"varchar")_","
	. set fcomment(i)=$select($data(comments(i)):" -- "_comments(i),1:"")
	write "DROP TABLE IF EXISTS SYSLOG_DATA KEEPDATA;",!
	write "CREATE TABLE SYSLOG_DATA -- Primary keys are reverse engineered from __CURSOR",!,"(",!
	; Write column definitions for key columns (subscripts)
	for i=1:1:nkeyflds do
	. set tmp=keyflds(i)
	. write " ",$zpiece(tmp,";",1)," ",$zpiece(tmp,";",2),", --",$zpiece(tmp,";",3),!
	; Write column definitions for non-key columns, structured data in pieces of the tree root
	for i=1:1:lastfnum write " ",fname(i),ftype(i),fcomment(i),!
	; Write column definitions for non-key columns, binary data in subtree nodes known to %YDBSYSLOG
	set lastfnum=$order(binflds(""),-1)
	for i=1:1:lastfnum do
	. write " ",$zwrite(binflds(i))," varchar GLOBAL ""^%ydbSLOG("
	. for j=1:1:nkeyflds write "keys(",$zconvert($ztranslate($zpiece(keyflds(j),";",1),"`"),"l"),"),"
	. write """""",binflds(i),""""")"" delim """",",!
	do:+$get(scanflag)
	. ; Write column definitions for non-key columns, data in subtree nodes of the database, but not known to %YDBSYSLOG
	. do gettags(.tagcnt)
	. set fname=""
	. for  set fname=$order(tagcnt(fname)) quit:'$zlength(fname)  do:"fld"'=fname
	. . write " ",$zwrite(fname)," varchar GLOBAL ""^%ydbSLOG("
	. . for j=1:1:nkeyflds write "keys(""""",$zconvert($zpiece(keyflds(j),";",1),"l"),"""""),"
	. . write """""",fname,""""")"" delim """",",!
	write " PRIMARY KEY (",!
	for i=1:1:nkeyflds-1 write " ",$zpiece(keyflds(i),";",1),",",!
	write $zpiece(keyflds(nkeyflds),";",1),!
	write ")) GLOBAL ""^%ydbSLOG"" delim (0);",!
	quit

; Except for error message texts, labels below are normally accessed only from within this routine

; Ensure that there is a separate YDBSLOG region with ^%ydbSLOG* (including capitalization variants)
; mapped to it. The database file is in the same directory, and using the same environment variables
; as the DEFAULT region, but unjournaled and using the MM access method by default, as the data can
; be reloaded from journalctl.
ensurereg
	new deffile,flag,g,i,io,l,line,o,reg,regdir,s,tmp
	set err=0,flag=1,io=$io,reg=""
	for  set reg=$view("gvnext",reg)  quit:'$zlength(reg)  set:"YDBSLOG"=reg flag=0
	do:flag
	. set deffile=$zpiece($$^%PEEKBYNAME("gd_segment.fname","DEFAULT"),$zchar(0),1)
	. set tmp=$zlength(deffile,"/"),regdir=$select(tmp-1:$zpiece(deffile,"/",1,tmp-1)_"/",1:"")
	. open "gde":(shell="/bin/sh":command="$ydb_dist/yottadb -run GDE":stderr="err")::"pipe"
	. use "gde"
	. write "add -region ydbslog -record_size=1048576 -key_size=1019 -autodb -dynamic_segment=ydbslog -nojournal",!
	. write "add -segment ydbslog -noasyncio -access_method=mm -file_name=""",regdir,"%ydbslog.dat""",!
	. for s="s","S" for l="l","L" for o="o","O" for g="g","G" write "add -name %ydb",s,l,o,g,"* -region=ydbslog",!
	. write "exit",! write /eof
	. use "err"
	. set err=0 for i=1:1 read line(i) quit:$zeof  set:$zfind(line(i),"Verification FAILED") err=1
	. use io close "gde"
	. do:err
	. . for i=1:1 quit:'$data(line(i))  write line(i),!
	. . set $ecode=",U247,"
	. view "gbldirload":$zgbldir
	quit

; Get information about tags in the unstructured data nodes. Used by OCTODDL, and useful for developers
; Uses variable from caller: binflds
gettags(tagcnt,datalen)
	new binfldsx,Cb,Ci,Cm,Cs,Ct,Cx,data,fld,fldlen,i,tmp
	if '$data(binflds) for i=1:1 set tmp=$text(binflds+i) quit:" "=tmp  set binflds(i)=$zpiece(tmp,";",2)
	for i=1:1:$order(binflds(""),-1) set binfldsx(binflds(i))=""
	set fldlen=0
	set Cs="" for  set Cs=$order(^%ydbSLOG(Cs)) quit:'$zlength(Cs)  do
	. set Cb="" for  set Cb=$order(^%ydbSLOG(Cs,Cb)) quit:'$zlength(Cb)  do
	. . set Ci="" for  set Ci=$order(^%ydbSLOG(Cs,Cb,Ci)) quit:'$zlength(Ci)  do
	. . . set Ct="" for  set Ct=$order(^%ydbSLOG(Cs,Cb,Ci,Ct)) quit:'$zlength(Ct)  do
	. . . . set Cm="" for  set Cm=$order(^%ydbSLOG(Cs,Cb,Ci,Ct,Cm)) quit:'$zlength(Cm)  do
	. . . . . set Cx="" for  set Cx=$order(^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx)) quit:'$zlength(Cx)  do
	. . . . . . set fld="" for  set fld=$order(^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx,fld)) quit:'$zlength(fld)  do:'$data(binfldsx(fld))
	. . . . . . . if $increment(tagcnt("fld",$$istype(fld))) set:$zlength(fld)>fldlen fldlen=$zlength(fld)
	. . . . . . . set data=^(fld),tmp=$$istype(data)
	. . . . . . . if $increment(tagcnt(fld,tmp)) set:$zlength(data)>+$get(datalen(fld,tmp)) datalen(fld,tmp)=$zlength(data)
	quit

; Output help text
help    new j,k,label,tmp
        set label=$text(+0)
        for j=1:1 set tmp=$piece($text(@label+j),"; ",2) quit:""=tmp  do
        . write $piece(tmp,"$text(+0)",1) for k=2:1:$length(tmp,"$text(+0)") write $text(+0),$piece(tmp,"$text(+0)",k)
        . write !
        quit

; Determine whether a string is a valid hexadecimal number
ishex(str)
	new tmp
	set tmp=$zextract(str,3,$zlength(str))
	quit "0x"=$zextract(str,1,2)&'$zlength($ztranslate(tmp,"0123456789ABCDEFabcdef"))

; Determine whether a value is numeric, text, or binary
istype(val)
	quit:$zchar(0)]]val "numeric"
	quit:val?.an "alphanumeric"
	quit:val?.anp "text"
	quit "binary"

; Process journalctl lines from an M mode device setup by the caller
proclines
	new field,flds,i,len,lenbin,line,linenum,rdlen,tmp,value
	new Cb,Ci,Cm,Cs,Ct,Cx			; Local variables for __CURSOR records
	do rdflds(.flds)			; Set piece numbers & data types for ^%ydbSLOG
	set line=""
	for linenum=1:1 read:'$zlength(line) line quit:$zeof  do
	. ; First line of a record is __CURSOR. It is technically an opaque string, but reverse engineering
	. ; shows that it is composed of pieces. They are pulled apart and use as subscripts in a different
	. ; order to avail of database key compression for faster access and more efficient storage.
	. if "__CURSOR="=$zextract(line,1,9) do
	. . set Cs="0x"_$zpiece($zpiece(line,"=",3),";",1)		; likely UUID for a large number of syslog entries
	. . set Ci=$$FUNC^%HD($zpiece($zpiece(line,"=",4),";",1))	; likely syslog record number
	. . set Cb="0x"_$zpiece($zpiece(line,"=",5),";",1)		; likely _BOOT_ID
	. . set Cm=$$FUNC^%HD($zpiece($zpiece(line,"=",6),";",1))	; likely  monotonic timestamp since boot
	. . set Ct=$$FUNC^%HD($zpiece($zpiece(line,"=",7),";",1))	; likely realtime timestamp ($ZUT)
	. . set Cx="0x"_$zpiece(line,"=",8)				; likely UUID for this syslog entry
	. . set line=""
	. . for  read:'$zlength(line) line quit:'$zlength(line)!("__CURSOR="=$zextract(line,1,9))  do
	. . . ; Since YottaDB has a 32767 byte limit on READ, if the length of the line read
	. . . ; is 32767 bytes, assume that the line is longer than 32767 bytes and that one
	. . . ; or more READs are required. The downside of handling this edge case is that
	. . . ; if a journalctl export line is exactly 32767 bytes, the next line will be
	. . . ; concatenated onto this line, and not separately handled.
	. . . do:32767=$zlength(line)
	. . . . for  do  quit:32767>$zlength(tmp)
	. . . . . read tmp
	. . . . . set:1048576<($zlength(line)+$zlength(tmp)) $ecode=",U252,"
	. . . . . set line=line_tmp
	. . . set field=$zpiece(line,"=",1),value=$zpiece(line,"=",2,$zlength(line,"="))
	. . . if 1<$zlength(line,"=")  do				; non-binary field value
	. . . . if $data(flds(field)) set $zpiece(^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx),$zchar(0),flds(field))=value
	. . . . else  set ^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx,field)=value
	. . . . set line=""
	. . . else  do						; value is binary
	. . . . for i=1:1:8 read *tmp set lenbin(i)=tmp
	. . . . set len=lenbin(8)				; calculate length of binary field
	. . . . for i=7:-1:1 set len=len*256+lenbin(i)
	. . . . set:1048576<len $ecode=",U250,"
	. . . . do:len
	. . . . . ; Read binary message. Since the binary field  may have newlines that will terminate
	. . . . . ; reads, read in a loop till the entire field is read.
	. . . . . read value#len
	. . . . . for  set rdlen=(len-$zlength(value)) quit:0>=rdlen  do
	. . . . . . read tmp#$select(32767<=rdlen:32767,1:rdlen)
	. . . . . . set value=value_$zchar(10)_tmp
	. . . . . read line
	. . . . . if $data(flds(field))&'$zfind(value,$zchar(0)) set $zpiece(^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx),$zchar(0),flds(field))=value
	. . . . . else  set ^%ydbSLOG(Cs,Cb,Ci,Ct,Cm,Cx,field)=value
	. else  set $ecode=",U253,"					; first line of record is not __CURSOR
	quit

; Read the journalctl fields following jnlctlflds into local variables, which
; must be passed by reference if needed by the caller.
rdflds(fpos,dtype,comments,fnum)
	new fcomment,fname,ftype,i,line
	for i=1:1 set line=$text(jnlctlflds+i) quit:" "=line  do
	. set fname=$zpiece(line,";",2),ftype=$zpiece(line,";",3),fcomment=$zpiece(line,";",4,$zlength(line,";"))
	. set fnum(i)=fname,fpos(fname)=i
	. set:$zlength(ftype) dtype(i)=ftype
	. set:$zlength(fcomment) comments(i)=fcomment
	quit

; Fields reported by journalctl and not indexed by %YDBSYSLOG, in order of an ad hoc measurement.
; To be read successfully, this list of fields must be followed by a blank line or the end of file.
binflds
	;MESSAGE
	;_SELINUX_CONTEXT
	;SYSLOG_RAW
	;WP_OBJECT
	;WP_OBJECT_TYPE
	;COREDUMP_OPEN_FDS
	;COREDUMP_PROC_AUXV
	;COREDUMP_PROC_CGROUP
	;COREDUMP_PROC_LIMITS
	;COREDUMP_PROC_MAPS
	;COREDUMP_PROC_MOUNTINFO
	;COREDUMP_PROC_STATUS

; Fields reported by journalctl and indexed by %YDBSYSLOG, in order of an ad hoc measurement
; of their frequencies across a range of Linux servers and distributions. The frequencies are
; converted to piece numbers in ^%ydbSYSLOG, with more frequent fields having smaller piece
; numbers. When INGESTJNLCTL() encounters a field whose name does not appear below, it places
; it in a creates a sub-node with the field name as an additional subscript.
; - MESSAGE is not listed here, despite being a field that occurs in every syslog entry. The
;   reason is that it is free text, even binary, and therefore not easily cross referenced.
;   Ergo, MESSAGE fields go in as sub-nodes with "MESSAGE" as the last subscript.
; - When adding new fields, add them as additional pieces at the end, in order to ensure
;   upward compatibility of Octo table definitions.
; - Fields found to have binary data in the ad hoc measurement are not listed.
; - This list of fields must be followed by a blank line, or the end of file, in order to
;   be read successfully by the code.
; - A semi-colon separated string after the field name is the type of the field, defaulting
;   to VARCHAR if unspecified.
; - Any fourth semi-colon separated text is a comment in the SQL DDL for that field.
jnlctlflds
	;_HOSTNAME;;
	;_BOOT_ID;;UUID
	;__REALTIME_TIMESTAMP;integer
	;__MONOTONIC_TIMESTAMP;integer
	;_TRANSPORT
	;_MACHINE_ID;;/etc/machine-id
	;SYSLOG_IDENTIFIER
	;PRIORITY;integer
	;SYSLOG_FACILITY;integer
	;_PID;integer
	;_UID;integer
	;_GID;integer
	;_COMM
	;_CAP_EFFECTIVE;integer
	;_SYSTEMD_UNIT
	;_SYSTEMD_CGROUP;integer
	;_SYSTEMD_SLICE
	;_SOURCE_REALTIME_TIMESTAMP;integer
	;_EXE
	;_CMDLINE
	;_SYSTEMD_INVOCATION_ID;integer
	;_AUDIT_SESSION;integer
	;_AUDIT_LOGINUID;integer
	;SYSLOG_TIMESTAMP;integer
	;SYSLOG_PID;integer
	;_SYSTEMD_OWNER_UID;integer
	;_SYSTEMD_USER_SLICE
	;_SYSTEMD_SESSION
	;CODE_FILE
	;CODE_LINE
	;CODE_FUNC
	;TID;integer
	;MESSAGE_ID;;UUID
	;_SYSTEMD_USER_UNIT
	;JOB_TYPE
	;JOB_ID
	;JOB_RESULT
	;USER_UNIT
	;USER_INVOCATION_ID;;UUID
	;_RUNTIME_SCOPE
	;LEADER
	;SESSION_ID
	;USER_ID
	;UNIT
	;INVOCATION_ID;;UUID
	;_STREAM_ID
	;N_RESTARTS;integer
	;_SOURCE_MONOTONIC_TIMESTAMP;integer
	;NM_LOG_DOMAINS
	;NM_LOG_LEVEL
	;TIMESTAMP_BOOTTIME;integer
	;TIMESTAMP_MONOTONIC;integer
	;NM_DEVICE
	;CPU_USAGE_NSEC;integer
	;USERSPACE_USEC;integer
	;_AUDIT_ID
	;_AUDIT_TYPE
	;_AUDIT_TYPE_NAME
	;_KERNEL_DEVICE
	;_KERNEL_SUBSYSTEM
	;_UDEV_SYSNAME
	;_AUDIT_FIELD_APPARMOR
	;_AUDIT_FIELD_OPERATION
	;_AUDIT_FIELD_PROFILE
	;_AUDIT_FIELD_NAME
	;_AUDIT_FIELD_DENIED_MASK
	;_AUDIT_FIELD_OUID
	;_AUDIT_FIELD_REQUESTED_MASK
	;_FSUID
	;_AUDIT_FIELD_CLASS
	;GLIB_OLD_LOG_API
	;GLIB_DOMAIN
	;_AUDIT_FIELD_ARCH
	;_AUDIT_FIELD_CODE
	;_AUDIT_FIELD_COMPAT
	;_AUDIT_FIELD_IP
	;_AUDIT_FIELD_SIG
	;_AUDIT_FIELD_SYSCALL
	;_UDEV_DEVNODE
	;UNIT_RESULT
	;DEVICE
	;_AUDIT_FIELD_INFO
	;COMMAND
	;EXIT_CODE
	;EXIT_STATUS
	;AUDIT_FIELD_ADDR
	;AUDIT_FIELD_APPARMOR
	;AUDIT_FIELD_BUS
	;AUDIT_FIELD_EXE
	;AUDIT_FIELD_HOSTNAME
	;AUDIT_FIELD_INTERFACE
	;AUDIT_FIELD_LABEL
	;AUDIT_FIELD_MASK
	;AUDIT_FIELD_MEMBER
	;AUDIT_FIELD_NAME
	;AUDIT_FIELD_OPERATION
	;AUDIT_FIELD_PATH
	;AUDIT_FIELD_PID
	;AUDIT_FIELD_SAUID
	;AUDIT_FIELD_TERMINAL
	;AUDIT_FIELD_PEER_LABEL
	;AUDIT_FIELD_PEER_PID
	;INTERFACE
	;PULSE_BACKTRACE
	;_AUDIT_FIELD_CAPABILITY
	;_AUDIT_FIELD_CAPNAME
	;AVAILABLE
	;AVAILABLE_PRETTY
	;CURRENT_USE
	;CURRENT_USE_PRETTY
	;DISK_AVAILABLE
	;DISK_AVAILABLE_PRETTY
	;DISK_KEEP_FREE
	;DISK_KEEP_FREE_PRETTY
	;JOURNAL_NAME
	;JOURNAL_PATH
	;LIMIT
	;LIMIT_PRETTY
	;MAX_USE
	;MAX_USE_PRETTY
	;CONFIG_FILE
	;CONFIG_LINE
	;BOLT_LOG_CONTEXT
	;BOLT_TOPIC
	;_LINE_BREAK
	;SEAT_ID
	;KERNEL_USEC;integer
	;THREAD_ID;integer
	;SLEEP
	;BOLT_DOMAIN_NAME
	;BOLT_DOMAIN_UID
	;ACTION
	;OPERATOR
	;N_DROPPED;integer
	;OBJECT_AUDIT_LOGINUID;integer
	;OBJECT_AUDIT_SESSION
	;OBJECT_CAP_EFFECTIVE
	;OBJECT_COMM
	;OBJECT_GID;integer
	;OBJECT_PID;integer
	;OBJECT_SELINUX_CONTEXT
	;OBJECT_SYSTEMD_CGROUP
	;OBJECT_SYSTEMD_INVOCATION_ID;integer
	;OBJECT_SYSTEMD_OWNER_UID;integer
	;OBJECT_SYSTEMD_SESSION
	;OBJECT_SYSTEMD_SLICE
	;OBJECT_SYSTEMD_UNIT
	;OBJECT_SYSTEMD_USER_SLICE
	;OBJECT_UID;integer
	;ERRNO;integer
	;BOLT_DEVICE_NAME
	;BOLT_DEVICE_STATE
	;BOLT_DEVICE_UID;integer
	;OBJECT_CMDLINE
	;OBJECT_EXE
	;EXECUTABLE
	;BOOTIME_USEC;integer
	;MONOTONIC_USEC;integer
	;REALTIME_USEC;integer
	;SHUTDOWN
	;BOLT_VERSION
	;ERROR_CODE
	;ERROR_DOMAIN
	;ERROR_MESSAGE
	;LIBVIRT_SOURCE
	;LIBVIRT_CODE
	;LIBVIRT_DOMAIN
	;ADDRESS
	;GATEWAY
	;NM_CONNECTION
	;PREFIXLEN
	;GNOME_SHELL_EXTENSION_NAME
	;GNOME_SHELL_EXTENSION_UUID
	;_AUDIT_FIELD_TARGET
	;WHERE
	;QT_CATEGORY
	;COREDUMP_CGROUP
	;COREDUMP_CMDLINE
	;COREDUMP_COMM
	;COREDUMP_CWD
	;COREDUMP_ENVIRON
	;COREDUMP_EXE
	;COREDUMP_FILENAME
	;COREDUMP_GID;integer
	;COREDUMP_HOSTNAME
	;COREDUMP_OWNER_UID;integer
	;COREDUMP_PACKAGE_JSON
	;COREDUMP_PID;integer
	;COREDUMP_RLIMIT
	;COREDUMP_ROOT
	;COREDUMP_SIGNAL;integer
	;COREDUMP_SIGNAL_NAME
	;COREDUMP_SLICE
	;COREDUMP_TIMESTAMP;integer
	;COREDUMP_UID;integer
	;COREDUMP_UNIT
	;COREDUMP_SESSION;integer
	;COREDUMP_USER_UNIT
	;INITRD_USEC;integer

; Reverse engineered fields of the __CURSOR record, in the order of ^%ydbSLOG subscripts.
; To be read successfully, this list of fields must be followed by a blank line or the end of file.
keyflds
	;CURSOR_SYSLOG_UUID;varchar;Cs (Syslog UUID)
	;CURSOR_BOOT_ID;varchar;Cb (Boot UUID)
	;CURSOR_SYSLOG_REC_NUM;integer;Ci (record number)
	;CURSOR_REALTIME_TIMESTAMP;integer;Ct (realtime timestamp)
	;CURSOR_BOOT_ID_MONOTONIC_TIMESTAMP;integer;Cm (monotonic timestamp since boot)
	;CURSOR_SYSLOG_REC_UUID;varchar;Cx (UUID for this entry)

;	Error message texts
U246	;"-F-ILLFROMCMDLINE Invoke entryref from another program, not command line"
U247	;"-F-GDEERR Global directory verification failed; see above"
U248	;"-F-ILLOPTS --boot and --follow options are mutually exclusive"
U249    ;"-F-ILLCMDLINE Illegal command line starting with: --"_cmdline
U250	;"-F-FIELDTOLONG Binary field "_field_" following line "_linenum_" exceeds 1048576 bytes"
U251	;"-F-LINETOOLONG Line "_linenun_" exceeds 1048576 bytes; field is "_$zpiece(line,"=",1)
U252	;"-F-BADCMDOPT Command line """_jnlctlcmd_""" reported error; first line of stderr is """_line_""""
U253	;"-F-NOCURSORREC First line of journalctl export record """_line_"""; expecting __CURSOR"
U254	;"-F-BADBOOTPARM Invalid value """_boot_""" for --boot option"
U255	;"-F-BADINVOCATION Invocation from another program must specify a label;  use yottadb -run "_$text(+0)_" to execute from top of routine"