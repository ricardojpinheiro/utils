program less;
{
* Print lines on the standard output with some nice uses.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

const
  UpArrow = #30;
  DownArrow = #31;
  LeftArrow = #28;
  RightArrow = #29;
  ESC = #27;
  Enter = #13;
  Null = #00;
  Select = #24; 
  Home = #11;
  Ins = #18;
  Del = #127;

Type
    TParameterVector = array [1..2] of string[80];

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName: byte;
    hInputFile: text;
    nDrive: byte;
    Lines: integer;
    i, j, k, l, counter: integer;
    Character: char;
    EndOfFile, Beginning, Finish, NumberedLines, PrintTab: boolean;
    Registers: TRegs;

    PrintString: TString;

(* Finds the last occurence of a chat into a string. *)

function LastPos(Character: char; Phrase: TString): integer;
var
    i: integer;
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
    FirstTwoDotsFound, LastBackSlashFound: byte;
    APPEND: string[7];
    Path, Temporary: TFileName;
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

procedure LessHelp;
begin
    clrscr;
    fastwriteln('Usage: less <file>.');
    fastwriteln('Print file on the standard output.');
    writeln;
    fastwriteln('File: Text file.');
    writeln;
    fastwriteln('Parameters: ');
    fastwriteln('/h - Display this help and exit.');
    fastwriteln('/v - Output version information & exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure LessVersion;
begin
    clrscr;
    fastwriteln('less version 1.0'); 
    fastwriteln('Copyright (c) 2020 Brazilian MSX Crew.');
    fastwriteln('Some rights reserved.');
    writeln;
    fastwriteln('License GPLv3+: GNU GPL v. 3 or later ');
    fastwriteln('<https://gnu.org/licenses/gpl.html>');
    fastwriteln('This is free software: you are free to');
    fastwriteln('change and redistribute it. There is ');
    fastwriteln('NO WARRANTY to the extent permitted ');
    fastwriteln('by law.');
    writeln;
    halt;
end;

begin
(*  Initializing some variables. *)
    Character := ' ';
    Beginning := false;
    Finish := false;
    NumberedLines := false;
    PrintTab := false;
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
        if paramcount = 0 then LessHelp;

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
                Character := upcase(Temporary[2]);
                if Temporary[1] = '/' then
                begin
                    delete(Temporary, 1, 2);

(*  Parameters. *)

                    case Character of
                        'B': Beginning := true;
                        'E': Finish := true;
                        'H': LessHelp;
                        'N': NumberedLines := true;
                        'T': PrintTab := true;
                        'V': LessVersion;
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

        assign (hInputFile, InputFileName);
        reset (hInputFile);

        Lines := 1;
        while Not EndOfFile do
        begin
            EndOfFile := EOF(hInputFile);
            fillchar(PrintString, sizeof(PrintString), ' ' );
            
            readln (hInputFile, PrintString);
            insert(chr(32), PrintString, 1);

(*  Here the program print the file. *)
            
            if Beginning = true then insert('$', PrintString, 1);
            if NumberedLines = true then
            begin
                str(Lines, TemporaryNumber);
                PrintString := concat(' ', TemporaryNumber, ' ', PrintString);
            end;
            if Finish = true then PrintString := concat(PrintString, '$' );
            if PrintTAB = true then
                for j := 1 to Length(PrintString) do
                    if PrintString[j] = #9 then
                    begin
                        delete(PrintString, j, 1);
                        insert('^I', PrintString, j);
                    end;
            
            Lines := Lines + 1;

            writeln(PrintString);
        end;

(*  Close file. *)

        CheatAPPEND(' ');
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        close(hInputFile);
    end;
end.
