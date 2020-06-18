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
{$i d:blink.inc}

Const
    TotalBufferSize = 767;
    BufferSize = 511;
    MaxLines = 16250;
    b = 251;

Type
    TOutputString = array[1..255] of char;
    TFourStates = (After, Before, Middle, Nothing);

Var
    MSXDOSversion: TMSXDOSVersion;
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName: byte;
    nDrive, BlockReadResult: byte;
    NewPosition, RandomLines, ValReturn: integer;
    EndOfFile: integer;
    Position, PositionsInOutputString: integer;
    i, j, k, l, counter, MatchLines, Lines: integer;
    Character, TemporaryChar: char;
    SeekResult, fEOF, Count, Found, Ignore, LineNumber, Reverse, ExtendedMode: boolean;
    Registers: TRegs;
    FourStates: TFourStates;
    
    ForegroundColor:    Byte Absolute    $F3E9; { Foreground color                        }
    BackgroundColor:    Byte Absolute    $F3EA; { Background color                        }
    BorderColor:        Byte Absolute    $F3EB; { Border color                            }
    
    Buffer: Array[0..1, 0..TotalBufferSize] Of Byte;
    BeginningOfLine: Array[0..MaxLines] of Integer;
    OutputString: TOutputString;
    temporario, PrintString, Pattern: TString;

(* Here we use MSX-DOS 2 to do the error handling. *)

procedure ErrorCode (ExitsOrNot: boolean);
var
    ErrorCodeNumber: byte;
    ErrorMessage: TMSXDOSString;
    
begin
    ErrorCodeNumber := GetLastErrorCode;
    GetErrorMessage (ErrorCodeNumber, ErrorMessage);
    WriteLn (ErrorMessage);
    if ExitsOrNot = true then exit;
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
    fastwriteln('for the input file.');
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

function RabinKarp (Pattern: TString; Text: TString): integer;
var
    HashPattern, HashText, Bm, j, LengthPattern, LengthText, Result: integer;
    Found : Boolean;
  
begin

(*  Initializing variables. *)

    Found := False;
    Result := 0;
    LengthPattern := length(Pattern);
    HashPattern := 0;
    HashText := 0;
    Bm := 1;
    LengthText := length(Text);

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
var
    k: integer;
    
    procedure ReadLineFile (l: integer);
    begin
        fillchar(OutputString, sizeof(OutputString), ' ' );
        ReadLineFromFile (l, PositionsInOutputString , OutputString);
    end;

    procedure WriteGrep (l: integer);
    begin
        if ExtendedMode = false then
            write(chr(32))
        else
            fastwrite(chr(32));
        if LineNumber = true then
            if ExtendedMode = false then
                write(l, ':')
            else
            begin
                fillchar(temporario, sizeof(temporario), ' ' );
                str(l, temporario);
                temporario := temporario + ':';
                fastwrite(temporario);
            end;
        for j := 1 to PositionsInOutputString do
            if ExtendedMode = false then
                write(OutputString[j])
            else
                if OutputString[j] <> #13 then
                    fastwrite(OutputString[j]);
        if ExtendedMode = true then
            Blink(Position + 1, WhereY, Length(Pattern));
        writeln;
        counter := counter + 1;
    end;

begin
    if Count = false then
    begin
        case FourStates of
            After: begin
                        for k := i to i + Lines do
                        begin
                            ReadLineFile(k);
                            WriteGrep(k);
                        end;
                    end;
            Before: begin
                        for k := i - Lines to i do
                        begin
                            ReadLineFile(k);
                            WriteGrep(k);
                        end;
                    end;
            Middle: begin
                        for k := (i - Lines) to (i + Lines) do
                        begin
                            ReadLineFile(k);
                            WriteGrep(k);
                        end;
                    end;
            Nothing: WriteGrep(i);
        end;
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
    Position := 0;
    MatchLines := maxint;
    FourStates := Nothing;
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

(*  No parameters, command prints the help. *)
        if paramcount = 0 then GrepHelp;

(*  The first parameter should be the pattern. *)
        Pattern := paramstr(1);

(*  The second parameter should be the file (or the standard input). *)
        InputFileName := paramstr(2);

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

(*  Parameters. *)

                case Character of
                    'A': FourStates := After;
                    'B': FourStates := Before;
                    'C': FourStates := Middle;
                    'H': GrepHelp;
                    'I': Ignore := true;
                    'M': Val(Temporary, MatchLines, ValReturn);
                    'N': LineNumber := true;
                    'O': Count := true;
                    'R': Reverse := true;                        
                    'V': GrepVersion;
                    'Z': ExtendedMode := true;
                end;
                if FourStates <> Nothing then Val(Temporary, Lines, ValReturn);
            end;
        end;

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


        if ExtendedMode = true then
        begin
            ClearAllBlinks;
            SetBlinkColors(BackgroundColor, ForegroundColor);
            SetBlinkRate(15, 0);
            clrscr;
        end;

(*  Here the program do the search in the file. *)

        if Ignore = true then
            for j := 1 to Length(Pattern) do
                Pattern[j] := upcase(Pattern[j]);

        i := 1;
        counter := 0;
        while (i <= EndOfFile) do
        begin
            fillchar(OutputString, sizeof(OutputString), ' ' );
            ReadLineFromFile (i, PositionsInOutputString , OutputString);
            for j := 1 to PositionsInOutputString do
            begin
                if Ignore = true then PrintString[j] := upcase(OutputString[j])
                else PrintString[j] := OutputString[j];
            end;
            insert(chr(32), PrintString, 1);
            PrintString[0] := chr(PositionsInOutputString + 1);
            Position := RabinKarp(Pattern, PrintString);
            if Reverse = false then 
                if Position <> 0 then PrintGrep;
            if Reverse = true then 
                if Position = 0 then PrintGrep;
            i := i + 1;
            if MatchLines < maxint then
                if counter = MatchLines then
                    i := EndOfFile + 1;
        end;

        if Count = true then 
        begin
            str(counter, temporario);
            if ExtendedMode = true then
                fastwriteln(temporario)
            else
                writeln(temporario);
        end;

        if ExtendedMode = true then
        begin
            readln;
            ClearAllBlinks;
        end;

(*  Close file. *)

        if (not FileClose(hInputFileName)) then ErrorCode(true);
        exit;
    end;
end.
