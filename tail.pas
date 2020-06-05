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

Const
    TotalBufferSize = 767;
    BufferSize = 511;
    MaxLines = 17500;

Type
    TParameterVector = array [1..4] of string[80];
    TOutputString = array[1..255] of char;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName: TFileName;
    Temporary: string[80];
    TemporaryNumber: string[5];
    hInputFileName, nDrive, BlockReadResult: byte;
    NewPosition, NumberLines, NumberBytes, Bytes, Lines: integer;
    EndOfFile, TotalBytes, ValReturn, PositionsInOutputString: integer;
    i, j, k, l, counter: integer;
    Character: char;
    SeekResult, fEOF: boolean;
    Registers: TRegs;

    Buffer: array[0..1, 0..TotalBufferSize] of byte;
    BeginningOfLine: array[0..MaxLines] of integer;
    OutputString: TOutputString;

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

procedure TailHelp;
begin
    clrscr;
    fastwriteln(' Usage: tail <file> <parameters>.');
    fastwriteln(' Output the last part of file.');
    writeln;
    fastwriteln(' File: Text file from where we are ');
    fastwriteln(' getting lines.');
    writeln;
    fastwriteln(' Parameters: ');
    fastwriteln(' /h - Display this help and exit.');
    fastwriteln(' /c<NUM> - Print the first NUM bytes');
    fastwriteln(' of each file.');
    fastwriteln(' /n<NUM> - Print the first NUM lines');
    fastwriteln(' of each file.');
    fastwriteln(' /v - Output version information and');
    fastwriteln(' exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure TailVersion;
begin
    clrscr;
    fastwriteln('tail version 1.0'); 
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
    TotalBytes := 0;
    fEOF := false;
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

(*  Parameter /n<count>. Save it into a integer variable. *)
(*  Parameter /o<file>. Save it into a string variable. *)
(*  Parameter /r. Save it into a boolean variable. *)

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
                Character := chr(Buffer[1,i]);
                if j > 1 then l := 0;
                if Character = #13 then
                begin
                    BeginningOfLine[j] := k + l;
                    TotalBytes := TotalBytes + k + l;
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
        TotalBytes := TotalBytes - 1;

(*  Here the program print n bytes. *)

        if NumberBytes > 0 then
        begin
            i := 0;
            Lines := EndOfFile;
            Bytes := NumberBytes;

            if NumberBytes < TotalBytes then
            begin
                while i < NumberBytes do
                begin
                    i := i + BeginningOfLine[Lines];
                    Lines := Lines - 1;
                end;
                Lines := Lines + 1;
                for i := EndOfFile downto Lines + 1 do
                    Bytes := Bytes - BeginningOfLine[i];
                Bytes := BeginningOfLine[Lines + 1] - Bytes;
            end
            else
            begin
                Lines := EndOfFile + 1;
                Bytes := 0;
            end;

            for i := Lines to EndOfFile do
            begin
                fillchar(OutputString, sizeof(OutputString), ' ' );
                ReadLineFromFile (i, PositionsInOutputString , OutputString);
                if i <> Lines then Bytes := 1;
                write(chr(32));
                for j := Bytes to PositionsInOutputString do
                    write(OutputString[j]);
                writeln;
            end;

(*  Close file. *)

            if (not FileClose(hInputFileName)) then ErrorCode(true);
            exit;
        end;

(*  Here the program print last n lines. *)

        if NumberLines > 0 then
        begin
            if NumberLines > EndOfFile then NumberLines := EndOfFile;
            for i := (EndOfFile - NumberLines) + 1 to EndOfFile do
            begin
                fillchar(OutputString, sizeof(OutputString), ' ' );
                ReadLineFromFile (i, PositionsInOutputString , OutputString);
                write(chr(32));
                for j := 1 to PositionsInOutputString do
                    write(OutputString[j]);
                writeln;
            end;

(*  Close file. *)

            if (not FileClose(hInputFileName)) then ErrorCode(true);
            exit;
        end;
    end;
end.
