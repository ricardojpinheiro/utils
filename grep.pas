program grep;
{
* Print lines that match patterns.
* Compile it using TP3 - more free memory.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

Const
    TotalBufferSize = 767;
    BufferSize = 511;
    MaxLines = 100;

Type
    TParameterVector = array [1..7] of string[80];
    TOutputString = array[1..255] of char;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName: byte;
    nDrive, BlockReadResult: byte;
    NewPosition, RandomLines, ValReturn: integer;
    EndOfFile: integer;
    Result, PositionsInOutputString: integer;
    i, j, k, l, counter, MatchLines: integer;
    Character, TemporaryChar: char;
    SeekResult, fEOF, Count, Found, Ignore, LineNumber, Reverse: boolean;
    Registers: TRegs;

    Buffer: Array[0..1, 0..TotalBufferSize] Of Byte;
    BeginningOfLine: Array[0..MaxLines] of Integer;
    OutputString: TOutputString;
    PrintString, Pattern: TString;

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

(*  Reads a random line from a file. if UsesOutputFileName is true, then
    it will be send to a output file. *)
    
procedure ReadLineFromFile (Line: integer; var PositionsInOutputString: Integer; var OutputString: TOutputString);
var
    TemporaryReal: real;
    Beginning, Finish, CurrentBlock, InitialBlock, FinalBlock: integer;
    PositionsInTheBuffer, i, j: integer;
    Character: char;

begin
    TemporaryReal := 0.0;

(*  Move seek pointer to the beginning of the file. *)

    SeekResult := FileSeek (hInputFileName, 0, ctSeekSet, NewPosition);

(*  Several calculations to know which block is it. *)

    for i := 0 to Line - 1 do
        TemporaryReal := TemporaryReal + BeginningOfLine[i];
    
    Beginning := round(int(TemporaryReal)) - 1;
    Finish := Beginning + BeginningOfLine[Line] - 2;
    
    if Line = 1 then Beginning := Beginning + 2;
    
    InitialBlock := round(int(Beginning / (BufferSize + 1)));
    FinalBlock := Finish div (BufferSize + 1);

(*  Move to the InitialBlock-th position. *)

    for j := 1 to InitialBlock do
        if (not FileSeek (hInputFileName, BufferSize, ctSeekCur, NewPosition)) then
            ErrorCode(true);

(*  Read the k and k+1 blocks. *)

    for i := 0 to 1 do
    begin
        fillchar (Buffer[i], TotalBufferSize, 0);

        BlockReadResult := FileBlockRead(hInputFileName, Buffer[i], BufferSize);
        if (BlockReadResult = ctReadWriteError) then
            ErrorCode(true);

        for j := 1 to BufferSize do
            if (Buffer[i,j] = ord(13)) then Buffer[i,j] := ord(255);
    end;

(*  Copy the broken occurrence from the 2nd buffer to the 1st. *)
    
    k := 0;
    repeat
        Character := chr(Buffer[1, k]);
        Buffer[0, BufferSize + k] := ord(Character);
        k := k + 1;
    until Character = chr(255);
    
    Buffer[0, BufferSize + k] := ord(255);
    
    CurrentBlock := 0;
    PositionsInTheBuffer := Beginning - 1;
    PositionsInOutputString := 1;
    l := Beginning mod (BufferSize + 1) - 1 + InitialBlock;
    fillchar(OutputString, sizeof(OutputString), ' ' );

    while (PositionsInTheBuffer < Finish) do
    begin
        OutputString[PositionsInOutputString] := chr(Buffer[CurrentBlock, l]);
        if (l = BufferSize) then
        begin
            CurrentBlock := CurrentBlock + 1;
            l := 0;
        end;

         if OutputString[PositionsInOutputString] = chr(255) then 
            OutputString[PositionsInOutputString] := chr(13);

        PositionsInTheBuffer := PositionsInTheBuffer + 1;
        PositionsInOutputString := PositionsInOutputString + 1;
        l := l + 1;
    end;
end;

(*  Command help.*)

procedure GrepHelp;
begin
    clrscr;
    fastwriteln('Usage: grep <pattern> <file> <params>.');
    fastwriteln('print lines that match patterns.');
    fastwriteln('Pattern: Text to be found.');
    fastwriteln('File: Text file.');
    fastwriteln('Parameters: ');
        fastwriteln('/a<X> - Print X lines of trailing');
        fastwriteln('context after matching lines.');
        fastwriteln('/b<X> - Print X lines of trailing');
        fastwriteln('context before matching lines.');
        fastwriteln('/c<X> - Print X lines of output');
        fastwriteln('context.');
    fastwriteln('/h - Display this help & exit.');
    fastwriteln('/i - Ignore case distinctions.');
        fastwriteln('/m<X> - Stop reading a file after X');
        fastwriteln('matching lines.');
    fastwriteln('/n - Prefix each line of output with');
    fastwriteln('its line number.');
    fastwriteln('/o - Print a count of matching lines');
    fastwriteln('for the input file');
    fastwriteln('/r - Print non-matching lines.');
    fastwriteln('/v - Output version information & exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure GrepVersion;
begin
    clrscr;
    fastwriteln('grep version 1.0'); 
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

function RabinKarp (Pattern: TFileName; Text: TFileName): integer;
const
    b = 251;
var
    HashPattern, HashText, Bm, j, LengthPattern, LengthText, Result: integer;
    Found: Boolean;
begin

(*  Initializing variables. *)

    Found := False;
    Result := 0;
    LengthPattern := length (Pattern);
    HashPattern := 0;
    HashText := 0;
    Bm := 1;
    LengthText := length (Text);

(*  If there isn't any patterns to search, exit. *)

    if LengthPattern = 0 then
    begin
        Result := 1;
        Found := true;
    end;

    if LengthText >= LengthPattern then

(*  Calculating Hash *)

    for j := 1 to LengthPattern do
    begin
        Bm := Bm * b;
        HashPattern := round(int(HashPattern * b + ord(Pattern[j])));
        HashText := round(int(HashText * b + ord(Text[j])));
    end;

    j := LengthPattern;
  
(*  Searching *)

    while not Found do
    begin
        if (HashPattern = HashText) and (Pattern = Copy (Text, j - LengthPattern + 1, LengthPattern)) then
        begin
            Result := j - LengthPattern;
            Found := true
        end;
        if j < LengthText then
        begin
            j := j + 1;
            HashText := round(int(HashText * b - ord (Text[j - LengthPattern]) * Bm + ord (Text[j])));
        end
        else
            Found := true;
    end;
    RabinKarp := Result;
end;

procedure PrintGrep;
begin
    if Count = false then
    begin
        write(chr(32));
        if LineNumber = true then write(i, ':');
        for j := 1 to PositionsInOutputString do
            write(OutputString[j]);
        writeln;
        counter := counter + 1;
    end;
end;

begin
(*  Initializing some variables. *)
    counter := 0;
    nDrive := 0;
    NewPosition := 0;
    fEOF := false;
    Character := ' ';
    TemporaryChar := ' ';
    Count := false;
    Found := false;
    Ignore := false;
    LineNumber := false;
    Reverse := false;
    Result := 0;
    MatchLines := maxint;
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
        if paramcount = 0 then GrepHelp;

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

(*  Parameters. *)

                    case Character of
                        'A': begin
                            end;
                        'B': begin
                            end;
                        'C': begin
                            end;
                        'H': GrepHelp;
                        'I': Ignore := true;
                        'M': Val(Temporary, MatchLines, ValReturn);
                        'N': LineNumber := true;
                        'O': Count := true;
                        'R': Reverse := true;                        
                        'V': GrepVersion;
                    end;
                end;
            end;
        end;

(*  The first parameter should be the pattern. *)
        Pattern := ParameterVector[1];

(*  The second parameter should be the file (or the standard input). *)
        
        InputFileName := ParameterVector[2];

(*  Open file *)
        hInputFileName := FileOpen (InputFileName, 'r');

(*  if there is any problem regarding the opening process, show the error code. *)
        if (hInputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);

(*  Get file information. *)
        SeekResult := FileSeek( hInputFileName, 0, ctSeekSet, NewPosition );
    
        j := 1;
        k := 1;
        while not fEOF do
        begin
            counter := 0;
            fillchar (Buffer[1], BufferSize, 0);

            BlockReadResult := FileBlockRead(hInputFileName, Buffer[1], BufferSize);
            if (BlockReadResult = ctReadWriteError) then ErrorCode(true);
            
            for i := 0 to BufferSize do
                if Buffer[1,i] <> 0 then counter := counter + 1;

            i := 0;
            l := 2;
            while (i < BufferSize) do
            begin
                TemporaryChar := chr(Buffer[1,i]);
                if j > 1 then l := 0;
                if TemporaryChar = #13 then
                begin
                    BeginningOfLine[j] := k + l;
                    j := j + 1;
                    k := 0;
                end;
                i := i + 1;
                k := k + 1;
            end;

            if counter = 1 then fEOF := true;

        end;
        BeginningOfLine[0] := 0;
        BeginningOfLine[1] := BeginningOfLine[1] + 1;
        BeginningOfLine[EndOfFile] := BeginningOfLine[EndOfFile] - 1;
        EndOfFile := j - 1;

(*  Here the program do the search in the file. *)

        if Ignore = true then
            for j := 1 to Length(Pattern) do
                Pattern[j] := upcase(Pattern[j]);

        i := 1;
        counter := 0;
        while (i <= EndOfFile) or (counter <= MatchLines) do
        begin
            fillchar(OutputString, sizeof(OutputString), ' ' );
            ReadLineFromFile (i, PositionsInOutputString , OutputString);
            for j := 1 to PositionsInOutputString do
            begin
                if Ignore = true then PrintString[j] := upcase(OutputString[j])
                else PrintString[j] := OutputString[j];
            end;
            Result := RabinKarp(Pattern, PrintString);
            if Reverse = false then 
                if Result <> 0 then PrintGrep;
            if Reverse = true then 
                if Result = 0 then PrintGrep;
            i := i + 1;
        end;

        if Count = true then writeln(counter);

(*  Close file. *)

        if (not FileClose(hInputFileName)) then ErrorCode(true);
        exit;
    end;
end.
