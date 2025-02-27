program tail;
{
* output the last part of files.
* Compile it using TP3 - more free memory.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: array [1..2] of string[80];
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    NumberLines, Lines, TotalLines, ValReturn: integer;
    NumberBytes, TotalBytes, Bytes, Bytes2: real;
    i, j: integer;
    Character: char;
    hInputFileName: byte;
    hInputFile: text;
    LengthLines: array[1..maxint] of byte;
    PrintString: TString;

(* Finds the last occurence of a chat into a string. *)

function LastPos(Character: char; Phrase: TString): integer;
var
    i: byte;
    Found: boolean;
begin
    i := length(Phrase);
    Found := false;
    repeat
        if Phrase[i] = Character then
        begin
            LastPos := i + 1;
            Found := true;
        end;
        i := i - 1;
    until Found = true;
    if Not Found then LastPos := 0;
end;

(* Here we use the APPEND environment variable. *)

procedure CheatAPPEND (FileName: TFileName);
var
    i, FirstTwoDotsFound, LastBackSlashFound: byte;
    APPEND: string[7];
    Path, Temporary: TFileName;
    Registers: TRegs;
begin

(* Initializing some variables... *)

    fillchar(Path, sizeof(Path), ' ' );
    fillchar(Temporary, sizeof(Temporary), ' ' );
    APPEND[0] := 'A';   APPEND[1] := 'P';   APPEND[2] := 'P';
    APPEND[3] := 'E';   APPEND[4] := 'N';   APPEND[5] := 'D';
    APPEND[6] := #0;
    
(*  Sees if in the path there is a ':', used with drive letter. *)    
    
    FirstTwoDotsFound := Pos (chr(58), FileName);

(*  If there is a two dots...  *)
    
    if FirstTwoDotsFound <> 0 then
    begin
    
(*  Let me see where is the last backslash character...  *)

        LastBackSlashFound := LastPos (chr(92), FileName);
        Path := copy (FileName, 1, LastBackSlashFound);

(*  Copy the path to the variable. *)
        
        for i := 1 to LastBackSlashFound - 1 do
            Temporary[i - 1] := Path[i];
        Temporary[LastBackSlashFound] := #0;
        Path := Temporary;

(*  Sets the APPEND environment variable. *)
        
        with Registers do
        begin
            B := sizeof (Path);
            C := ctSetEnvironmentItem;
            HL := addr (APPEND);
            DE := addr (Path);
        end;
        MSXBDOS (Registers);
    end;
end;

(* Here we use MSX-DOS 2 to do the error handling. *)

procedure ErrorCode (ExitsOrNot: boolean);
var
    ErrorCodeNumber: byte;
    ErrorMessage: TMSXDOSString;
    
begin
    ErrorCodeNumber := GetLastErrorCode;
    GetErrorMessage (ErrorCodeNumber, ErrorMessage);
    WriteLn (ErrorMessage);
    if ExitsOrNot = true then
        Exit;
end;

(*  Command help.*)

procedure TailHelp;
begin
    clrscr;
    fastwriteln('Usage: tail <file> <parameters>.');
    fastwriteln('Output the last part of file.');
    writeln;
    fastwriteln('File: Text file from where we are ');
    fastwriteln('getting lines.');
    writeln;
    fastwriteln('Parameters: ');
    fastwriteln('/h - Display this help and exit.');
    fastwriteln('/c<NUM> - Print the last NUM bytes');
    fastwriteln('of each file.');
    fastwriteln('/n<NUM> - Print the last NUM lines');
    fastwriteln('of each file.');
    fastwriteln('/v - Output version information and');
    fastwriteln('exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure TailVersion;
begin
    clrscr;
    fastwriteln('tail version 2.0'); 
    fastwriteln('Copyright (c) 2020 Brazilian MSX Crew.');
    fastwriteln('Some rights reserved.');
    writeln;
    fastwriteln('License GPLv3+: GNU GPL v. 3 or later');
    fastwriteln('<https://gnu.org/licenses/gpl.html>');
    fastwriteln('This is free software: you are free to');
    fastwriteln('change and redistribute it. There is');
    fastwriteln('NO WARRANTY to the extent permitted');
    fastwriteln('by law.');
    writeln;
    halt;
end;

begin
(*  Initializing some variables. *)
    NumberLines := 10;
    NumberBytes := 0.0;
    TotalBytes := 0.0;
    TotalLines := 0;
    Character := ' ';
    fillchar(InputFileName, sizeof(InputFileName), ' ' );
    fillchar(TemporaryNumber, sizeof(TemporaryNumber), ' ' );

(*  if are we not running in a MSX-DOS 2 machine, exits. 
*   Else... Runs the program. *)

    GetMSXDOSVersion (MSXDOSversion);

    if (MSXDOSversion.nKernelMajor < 2) then
    begin
        fastwriteln('MSX-DOS 1.x not supported.');
        halt;
    end
    else 
    begin

(* No parameters, command prints the help. *)
        if paramcount = 0 then TailHelp;

(*  Clear variables. *)
        fillchar(ParameterVector, sizeof(ParameterVector), ' ' );

(*  Read parameters, and upcase them. *)
        for i := 1 to paramcount do
        begin
            Temporary := paramstr(i);
            for j := 1 to length(Temporary) do
                Temporary[j] := upcase(Temporary[j]);
            ParameterVector[i] := Temporary;
        end;
        
        if paramcount > 0 then
        begin
            for i := 1 to paramcount do
            begin
                Temporary := ParameterVector[i];
                Character := Temporary[2];
                if Temporary[1] = '/' then
                begin
                    delete(Temporary, 1, 2);

(*  Parameter /c<NUM>. Save it into a real variable. *)
(*  Parameter /n<NUM>. Save it into a integer variable. *)

                    case Character of
                        'H': TailHelp;
                        'N': begin
                                TemporaryNumber := copy (Temporary, 1, length(Temporary));
                                Val(TemporaryNumber, NumberLines, ValReturn);
                                NumberBytes := 0;
                            end;
                        'C': begin
                                TemporaryNumber := copy (Temporary, 1, length(Temporary));
                                Val(TemporaryNumber, NumberBytes, ValReturn);
                                NumberLines := 0;
                            end;
                        'V': TailVersion;
                        else    TailHelp;
                    end;
                end;
            end;
        end;

(*  The first parameter should be the file (or the standard input). *)
        InputFileName := ParameterVector[1];

(*  Cheats the APPEND environment variable. *)
        CheatAPPEND(InputFileName);

(*  Open file *)
        hInputFileName := FileOpen (InputFileName, 'r');

(*  if there is any problem regarding the opening process, show the error code. *)
        if (hInputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);

(*  Close file *)
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        
(*  Open file again, as a text file *)
        assign(hInputFile, InputFileName);
        reset(hInputFile);

        TotalLines := 0;
        TotalBytes := 0;

(*  Finds how many bytes and lines does the file has. *)
(*  It was necessary to use an array of bytes to know the length of each
*   line, so we can avoid opening the file several times. *)
        while not EOF(hInputFile) do
        begin
            fillchar(PrintString, sizeof(PrintString), ' ' );
            readln(hInputFile, PrintString);
            TotalLines := TotalLines + 1;
            LengthLines[TotalLines] := Length(PrintString) + 2;
            TotalBytes := TotalBytes + LengthLines[TotalLines];
        end;
        
        close(hInputFile);

(*  Open file a third time, so here we can print the lines or bytes *)
        assign(hInputFile, InputFileName);
        reset(hInputFile);

(*  Here the program print last n bytes. *)
        if NumberBytes > 0 then
        begin
            i := 0;
            Lines := TotalLines;
            Bytes := NumberBytes;

(*  Here the program knows where it will print the first byte and line, 
*   until the end of the file. It's tricky, I know. *)
            if NumberBytes < TotalBytes then
            begin
                while i < NumberBytes do
                begin
                    i := i + LengthLines[Lines];
                    Lines := Lines - 1;
                end;
                Lines := Lines + 1;
                for i := TotalLines downto Lines + 1 do
                    Bytes := Bytes - LengthLines[i];
                Bytes := LengthLines[Lines + 1] - Bytes;
            end
            else
            begin
                Lines := TotalLines + 1;
                Bytes := 0;
            end;

(*  Here is where it'll print the lines, starting with the line and byte
*   which was found before. *)
            i := 1;
            while not EOF(hInputFile) do
            begin
                fillchar(PrintString, sizeof(PrintString), ' ' );
                readln(hInputFile, PrintString);
                if i >= Lines then 
                begin
                    if i > Lines then Bytes := 1;
                    for j := round(int(Bytes)) to Length(PrintString) do
                        write(PrintString[j]);
                    writeln;
                end;
                i := i + 1;
            end;
        end;

(*  Here the program print last n lines. *)
(*  It's much easier than to print last n bytes, as you can see it. *)
        Lines := 0;
        if NumberLines > 0 then
        begin
            if NumberLines > TotalLines then NumberLines := TotalLines;
            while not EOF(hInputFile) do
            begin
                fillchar(PrintString, sizeof(PrintString), ' ' );
                readln(hInputFile, PrintString);
                Lines := Lines + 1;
                if (Lines >= TotalLines - NumberLines) then
                    writeln(PrintString);
            end;
        end;

(*  Close file. *)
        CheatAPPEND(' ');
        close(hInputFile);         
        exit;
    end;
end.
