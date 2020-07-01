program wc;
{
* count how many bytes, characters, words
* and lines are into a given file.
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
    InputFileName: TFileName;
    hInputFileName: byte;
    hInputFile: text;
    TotalLines, TotalBytes, TotalChars, TotalWords: real;
    i, j, LengthPrintString: integer;
    TemporaryChar, Character: char;
    Flag: boolean;
    Temporary, PrintString: string[255];

(* Finds the last occurence of a char into a string. *)

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

procedure WCHelp;
begin
    clrscr;
    fastwriteln('Usage: wc <file> <parameters>.');
    fastwriteln('print newline, word, and byte counts');
    fastwriteln('for each file.');
    writeln;
    fastwriteln('File: Text file from where we are ');
    fastwriteln('getting lines.');
    writeln;
    fastwriteln('Parameters: ');
    fastwriteln('/h - Display this help and exit.');
    fastwriteln('/c - Print the byte counts.');
    fastwriteln('/l - Print the newline counts.');
    fastwriteln('/m - Print the character counts.');
    fastwriteln('/w - Print the word counts.');
    fastwriteln('/v - Output version information and');
    fastwriteln('exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure WCVersion;
begin
    clrscr;
    fastwriteln('wc version 2.0'); 
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
    TotalBytes := 0.0;
    TotalChars := 0.0;
    TotalWords := 0.0;
    TotalLines := 0.0;
    Flag := false;
    Character := 'A';
    TemporaryChar := ' ';
    fillchar(InputFileName, sizeof(InputFileName), ' ' );

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
        if paramcount = 0 then WCHelp;

(*  Read parameters, and upcase them. *)
        for i := 1 to paramcount do
        begin
            Temporary := paramstr(i);
            for j := 1 to length(Temporary) do
                Temporary[j] := upcase(Temporary[j]);

            if paramcount > 1 then
            begin
                Character := Temporary[2];
                if Temporary[1] = '/' then
                begin
                    delete(Temporary, 1, 2);

(*  Parameters. *)

                    case Character of
                        'H': WCHelp;
                        'V': WCVersion;
                    end;
                end;
            end;
        end;

(*  The first parameter should be the file (or the standard input). *)
        InputFileName := paramstr(1);

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

(*  Finds how many bytes, characters and lines does the file has. *)
        while not EOF(hInputFile) do
        begin
            fillchar(PrintString, sizeof(PrintString), ' ' );
            readln(hInputFile, PrintString);
            LengthPrintString := Length(PrintString);
            if (Character = 'A') or (Character = 'L') then
                TotalLines := TotalLines + 1;

            if (Character = 'A') or (Character = 'C') then
                TotalBytes := TotalBytes + LengthPrintString + 2;
                
            if (Character = 'A') or (Character = 'M') then
                TotalChars := TotalChars + LengthPrintString;

            if (Character = 'A') or (Character = 'W') then
                for i := 1 to LengthPrintString do
                begin
                    TemporaryChar := PrintString[i];
                    if (ord(TemporaryChar) in [9,13,32]) then
                        Flag := true
                    else 
                        if Flag = true then
                        begin
                            TotalWords := TotalWords + 1;
                            flag := false;
                        end;
                end;
        end;
        
        CheatAPPEND(' ');
        close(hInputFile);

(*  C - Print how many bytes does the file has. *)
(*  L - Print how many lines does the file has. *)
(*  M - Print how many printable chars does the file has. *)
(*  W - Print how many words does the file has. *)
(*  A - Print everything about the file. *)
 
        case Character of
            'C': writeln(TotalBytes:0:0, ' ', InputFileName);
            'L': writeln(TotalLines:0:0, ' ', InputFileName);
            'M': writeln(TotalChars:0:0, ' ', InputFileName);
            'W': writeln(TotalWords:0:0, ' ', InputFileName);
            'A': writeln(TotalLines:0:0, ' ', TotalWords:0:0, ' ', TotalBytes:0:0, ' ', InputFileName);
            else WCHelp;
        end;
    end;
end.
