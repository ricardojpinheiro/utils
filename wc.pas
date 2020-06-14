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

Const
    TotalBufferSize = 767;
    BufferSize = 511;
    MaxLines = 18300;

Type
    TParameterVector = array [1..2] of string[80];
    TOutputString = array[1..255] of char;
    ASCII = set of 0..255;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName, nDrive, BlockReadResult: byte;
    NewPosition, NumberLines, NumberBytes, Bytes, Lines: integer;
    EndOfFile, ValReturn, PositionsInOutputString: integer;
    TotalBytes, TotalChars, TotalWords: real;
    i, j, k, l, counter: integer;
    TemporaryChar, PreviousChar, Character: char;
    SeekResult, fEOF: boolean;
    Registers: TRegs;

    Buffer: array[0..1, 0..TotalBufferSize] of byte;
    BeginningOfLine: array[0..MaxLines] of integer;
    OutputString: TOutputString;

    NoPrint, Print, AllChars: ASCII;

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
    fastwriteln('wc version 1.0'); 
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
    counter := 0;
    nDrive := 0;
    NewPosition := 0;
    NumberLines := 10;
    NumberBytes := 0;
    TotalBytes := 0.0;
    TotalChars := 0.0;
    TotalWords := 0.0;
    fEOF := false;
    Character := 'A';
    TemporaryChar := ' ';
    PreviousChar := ' ';
    AllChars := [0..255];
    NoPrint := [0..31,127,255];
    Print := AllChars - NoPrint;
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
        if paramcount = 0 then WCHelp;

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
        
        if paramcount > 1 then
        begin
            for i := 1 to 2 do
            begin
                Temporary := ParameterVector[i];
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
        InputFileName := ParameterVector[1];

(*  Open file *)
        hInputFileName := FileOpen (InputFileName, 'r');

(*  if there is any problem regarding the opening process, show the error code. *)
        if (hInputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);

(*  Get file information. *)
        SeekResult := FileSeek( hInputFileName, 0, ctSeekSet, NewPosition );
    
        j := 1;
        k := 1;
        while (fEOF = false) do
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

(*  Counts how many words the file has. *)

                if ((ord(PreviousChar) in [65..90]) or
                    (ord(PreviousChar) in [97..122])) and 
                    (ord(TemporaryChar) in [13,32]) then TotalWords := TotalWords + 1;

(*  Counts how many printable chars the file has. *)

                if (ord(TemporaryChar) in Print) then TotalChars := TotalChars + 1;
                if TemporaryChar = #13 then
                begin
                    BeginningOfLine[j] := k + l;
                    TotalBytes := TotalBytes + k + l;
                    
(*  Counts how many bytes the file has. *)                    
                    
                    j := j + 1;
                    k := 0;
                end;
                i := i + 1;
                k := k + 1;
                PreviousChar := TemporaryChar;
            end;

            if counter = 1 then fEOF := true;

        end;
        BeginningOfLine[0] := 0;
        BeginningOfLine[1] := BeginningOfLine[1] + 1;
        BeginningOfLine[EndOfFile] := BeginningOfLine[EndOfFile] - 1;
        EndOfFile := j - 1;
        TotalBytes := TotalBytes - 1;

(*  C - Print how many bytes does the file has. *)
(*  L - Print how many lines does the file has. *)
(*  M - Print how many printable chars does the file has. *)
(*  W - Print how many words does the file has. *)
(*  A - Print everything about the file. *)

        case Character of
            'C': writeln(TotalBytes:0:0, ' ', ParameterVector[1]);
            'L': writeln(EndofFile, ' ', ParameterVector[1]);
            'M': writeln(TotalChars:0:0, ' ', ParameterVector[1]);
            'W': writeln(TotalWords:0:0, ' ', ParameterVector[1]);
            'A': writeln(EndofFile, ' ', TotalWords:0:0, ' ', TotalBytes:0:0, ' ', ParameterVector[1]);
            else WCHelp;
        end;

(*  Close file. *)

        if (not FileClose(hInputFileName)) then ErrorCode(true);
        exit;
    end;
end.
