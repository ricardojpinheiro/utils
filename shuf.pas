program shuf;
{
* Shuffles lines from a given file.
* Compile it using TP3 - more free memory.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

Const
    MaxLines = 16384;

Type
    TRandomLines = Array[0..MaxLines] of Integer;

Var
    MSXDOSversion: TMSXDOSVersion;
    InputFileName, OutputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName: byte;
    hInputFile, hOutputFile: text;
    i, j, RandomLines, ValReturn: integer;
    Lines, TotalLines: real;
    Character: char;
    NumberedLines, RepeatedLines, UsesOutputFileName, SeekResult, fEOF: boolean;
    RandomNumbers: TRandomLines;
    PrintString: TString;

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

(* Quick sort to order the random lines vector. *)

procedure quicksort(var Vector: TRandomLines; Beginning, Finish: integer);
var 
    i, j, Middle, Pivot, Aux: integer;
    
begin
  i := Beginning;
  j := Finish;
  Middle := (Beginning + Finish) div 2;
  Pivot := Vector[Middle];

  while (i <= j) do
  begin
    while (Vector[i] < Pivot) and (i < Finish) do
      i := i + 1;

    while (Vector[j] > Pivot) and (j > Beginning) do
      j := j - 1;

    if (i <= j) then
    begin
      Aux := Vector[i];
      Vector[i] := Vector[j];
      Vector[j] := Aux;
      i := i + 1;
      j := j - 1;
    end;
  end;

  if (j > Beginning) then
    quicksort(Vector, Beginning, j);

  if (i < Finish) then
    quicksort(Vector, i, Finish);
end;

(*  Command help.*)

procedure ShufHelp;
begin
    clrscr;
    fastwriteln(' Usage: shuf <file> <parameters>.');
    fastwriteln(' Write a random permutation of the ');
    fastwriteln(' input lines to standard output.');
    writeln;
    fastwriteln(' File: Text file from where we are ');
    fastwriteln(' getting lines.');
    writeln;
    fastwriteln(' Parameters: ');
    fastwriteln(' /h - Display this help and exit.');
    fastwriteln(' /l - Number all output lines.');
    fastwriteln(' /n<COUNT> - Output at most COUNT lines.');
    fastwriteln(' /o<FILE>  - Write result to FILE');
    fastwriteln(' instead of standard output.');
    fastwriteln(' /r - Output lines can be repeated.');
    fastwriteln(' /v - Output version information and ');
    fastwriteln(' exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure ShufVersion;
begin
    clrscr;
    fastwriteln('shuf version 2.0'); 
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
    RandomLines := 0;
    UsesOutputFileName := false;
    fEOF := false;
    NumberedLines := false;
    RepeatedLines := false;
    Character := ' ';
    fillchar(InputFileName, sizeof(InputFileName), ' ' );
    fillchar(OutputFileName, sizeof(OutputFileName), ' ' );
    fillchar(TemporaryNumber, sizeof(TemporaryNumber), ' ' );
    randomize;

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
        if paramcount = 0 then 
            ShufHelp
        else
        begin
(*  Read parameters, and upcase them. *)
            for i := 1 to paramcount do
            begin
                Temporary := paramstr(i);
                for j := 1 to length(Temporary) do
                    Temporary[j] := upcase(Temporary[j]);
                Character := Temporary[2];
                if Temporary[1] = '/' then
                begin
                    delete(Temporary, 1, 2);

(*  Parameter /n<count>. Save it into a integer variable. *)
(*  Parameter /o<file>. Save it into a string variable. *)
(*  Parameter /r. Save it into a boolean variable. *)

                    case Character of
                        'H': ShufHelp;
                        'L': NumberedLines := true;
                        'N': begin
                                TemporaryNumber := copy (Temporary, 1, length(Temporary));
                                Val(TemporaryNumber, RandomLines, ValReturn);
                            end;
                        'O': begin
                                OutputFileName := copy (Temporary, 1, length(Temporary));
                                UsesOutputFileName := true;
                            end;
                        'R': RepeatedLines := true;
                        'V': ShufVersion;
                        else    ShufHelp;
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

        TotalLines := 0;

(*  Finds how many lines does the file has. *)
        while not EOF(hInputFile) do
        begin
            fillchar(PrintString, sizeof(PrintString), ' ' );
            readln(hInputFile, PrintString);
            TotalLines := TotalLines + 1;
        end;
        
        close(hInputFile);

(*  if OutputFileName has something, then we should open a second file for output. *)

        if UsesOutputFileName = true then
        begin
            assign(hOutputFile, OutputFileName);
            rewrite(hOutputFile);
        end;

(*  Show specific number of lines, defined by RandomLines. *)

        if RandomLines = 0 then
            RandomLines := round(int(TotalLines));

(*  Here the program generates all random numbers. *)

        for i := 1 to RandomLines do
            RandomNumbers[i] := random(round(int(TotalLines))) + 1;

(*  If there are any random number which is repeated, please choose other number. *)

        if (not RepeatedLines) then
            for i := 1 to RandomLines do
                for j := i + 1 to RandomLines do
                    if RandomNumbers[i] = RandomNumbers[j] then 
                        RandomNumbers[i] := random(round(int(TotalLines))) + 1;

(*  Let's sort the vector. *)
        quicksort (RandomNumbers, 1, RandomLines);
            
(*  Here is where the program prints the lines. *)
(*  Unfortunately, we'll open the file a third time... *)

        assign(hInputFile, InputFileName);
        reset(hInputFile);

(*  Main loop. *)
        Lines := 0;
            
        while not EOF(hInputFile) do
        begin
            fillchar(PrintString, sizeof(PrintString), ' ' );
            readln(hInputFile, PrintString);
            Lines := Lines + 1;
            for i := 1 to RandomLines do
                if Lines = RandomNumbers[i] then
                begin
                    if NumberedLines = false then
                        insert(' ', PrintString, 1)
                    else
                    begin
                        TemporaryNumber := ' ';
                        str(RandomNumbers[i], TemporaryNumber);
                        Temporary := concat(' Line ', TemporaryNumber, ': ');
                        insert(Temporary, PrintString, 1);
                    end;
                    if UsesOutputFileName = true then 
                        writeln(hOutputFile, PrintString)
                    else
                        writeln(PrintString);
                end;
        end;
        close(hInputFile);
        if UsesOutputFileName = true then close(hOutputFile);
    end;
end.
