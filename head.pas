program head;
{
* Print lines on the standard output.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

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
    Lines, MaxLines, ValResult: integer;
    i, j, k, l, counter: integer;
    Chars, Chars2, MaxChars: real;
    Character: char;
    EndOfFile, CharLimit, Beginning, Finish, NumberedLines, PrintTab: boolean;
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

procedure HeadHelp;
begin
    clrscr;
    fastwriteln(' Usage: head <file> <parameters>.');
    fastwriteln(' Output the first part of file.');
    writeln;
    fastwriteln(' File: Text file from where we are ');
    fastwriteln(' getting lines.');
    writeln;
    fastwriteln(' Parameters: ');
    fastwriteln('/b - Display $ at beginning of each');
    fastwriteln('line.');
    fastwriteln('/c<NUM> - Print the first NUM bytes');
    fastwriteln('of each file.');
    fastwriteln('/e - Display $ at end of each line.');
    fastwriteln('/h - Display this help and exit.');
    fastwriteln('/l<NUM> - Print the first NUM lines');
    fastwriteln('of each file.');
    fastwriteln('/n - Number all output lines.');
    fastwriteln('/t - Display TAB characters as ^I.');
    fastwriteln('/v - Output version information & exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure HeadVersion;
begin
    clrscr;
    fastwriteln('head version 2.0'); 
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
    CharLimit := false;
    Beginning := false;
    Finish := false;
    NumberedLines := false;
    EndOfFile := false;
    PrintTab := false;
    MaxLines := 10;
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
        if paramcount = 0 then HeadHelp;

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
                        'C': begin
                                CharLimit := true;
                                val(Temporary, MaxChars, ValResult);
                            end;
                        'E': Finish := true;
                        'H': HeadHelp;
                        'L': val(Temporary, MaxLines, ValResult);
                        'N': NumberedLines := true;
                        'T': PrintTab := true;
                        'V': HeadVersion;
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
        Chars := 0;
        Chars2 := 0;
        while Not EndOfFile do
        begin
            EndOfFile := EOF(hInputFile);
            fillchar(PrintString, sizeof(PrintString), ' ' );
            
            readln (hInputFile, PrintString);
            
            if CharLimit = true then
            begin
                Chars := Chars + Length(PrintString);
                if Chars > MaxChars then
                begin
                    counter := round(int(MaxChars - Chars2));
                    delete(PrintString, counter, Length(PrintString) - counter);
                    EndOfFile := true;
                end;
                Chars2 := Chars;
            end;

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

            writeln(PrintString);
            
            Lines := Lines + 1;
            
            if Lines > MaxLines then
                EndOfFile := true;
        end;

(*  Close file. *)

        CheatAPPEND(' ');
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        close(hInputFile);
    end;
end.
