program shuf;
{
* Shuffles lines from a given file.
* }

{$i d:types.inc}
{$i d:memory.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}
{$i d:dos2file.inc}
{$i d:fastwrit.inc}

Const
    TotalBufferSize = 1023;
    BufferSize = 511;
    MaxLines = 250;

Type
    TParameterVector = array [1..4] of TString;
    TOutputString = array[1..255] of char;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName, OutputFileName, Temporary: TFileName;
    TemporaryNumber: string[5];
    hInputFileName, hOutputFileName, nDrive: byte;
    BlockReadResult: byte;
    NewPosition, RandomLines, ValReturn: integer;
    SizeOfInputFile, EndOfFile: integer;
    PositionsInOutputString: integer;
    i, j, k, l, counter: integer;
    Character: char;
    RepeatedLines, UsesOutputFileName, SeekResult: boolean;
    fEOF: boolean;
    Registers: TRegs;
    
    Buffer: Array[0..1, 0..TotalBufferSize] Of Byte;
    BeginningOfLine: Array[0..MaxLines] of Integer;
    OutputString: TOutputString;
    PrintString: string[255];

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

(*  Reads a random line from a file. If UsesOutputFileName is true, then
    it will be send to a output file. *)
    
procedure ReadLineFromFile (Line: integer; var PositionsInOutputString: Integer; var OutputString: TOutputString);
var
    TemporaryReal: real;
    Beginning, Finish, CurrentBlock, InitialBlock, FinalBlock: integer;
    PositionsInTheBuffer: integer;
   
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
        If (not FileSeek (hInputFileName, BufferSize, ctSeekCur, NewPosition)) then
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
    
{
for i := 0 to 0 do
begin
    writeln('i: ', i, ' k: ', k, ' total: ', BufferSize + k);
    for j := BufferSize to BufferSize + k do
        write(chr(Buffer[1, j]));
end;
}
    CurrentBlock := 0;
    PositionsInTheBuffer := Beginning - 1;
    PositionsInOutputString := 1;
    l := Beginning mod (BufferSize + 1) - 1 + InitialBlock;
    fillchar(OutputString, sizeof(OutputString), ' ' );
{
    writeln(' InitialBlock: ', InitialBlock, ' FinalBlock: ', FinalBlock,
     ' Linha: ', Line, ' Beginning: ', Beginning, ' Finish: ', Finish, ' l: ', l);
}
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
{
        writeln('OutputString[',PositionsInOutputString,']=', OutputString[PositionsInOutputString],
        ' Buffer[', CurrentBlock, ',', l, ']=', chr(Buffer[CurrentBlock, l]), ' ');

        write(chr(Buffer[CurrentBlock,l]));

        write(OutputString[PositionsInOutputString]);
}        
        PositionsInTheBuffer := PositionsInTheBuffer + 1;
        PositionsInOutputString := PositionsInOutputString + 1;
        l := l + 1;
    end;

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
    fastwriteln('shuf version 0.1'); 
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
    counter := 0;
    nDrive := 0;
    NewPosition := 0;
    RandomLines := 0;
    fEOF := false;
    OutputFileName := '';
    fillchar(InputFileName, sizeof(InputFileName), ' ' );
    fillchar(TemporaryNumber, sizeof(TemporaryNumber), ' ' );
    randomize;

(*  If are we not running in a MSX-DOS 2 machine, exits. 
*   Else... Runs the program. *)

    GetMSXDOSVersion (MSXDOSversion);

    if (MSXDOSversion.nKernelMajor < 2) then
    begin
        writeln('MSX-DOS 1.x not supported.');
        halt;
    end
    else 
    begin

(* No parameters, command prints the help. *)
        if paramcount = 0 then ShufHelp;

(*  Clear variables. *)
        fillchar(ParameterVector, sizeof(ParameterVector), ' ' );

(*  Read parameters, and upcase them. *)
        for i := 1 to 4 do
        begin
            Temporary := paramstr(i);
            for j := 1 to length(Temporary) do
                Temporary[j] := upcase(Temporary[j]);
            ParameterVector[i] := Temporary;
        end;

(*  The first parameter should be the file (or the standard input). *)
        InputFileName := concat('D:', ParameterVector[1]);

(*  Open file *)
        hInputFileName := FileOpen (InputFileName, 'r');

(*  If there is any problem regarding the opening process, show the error code. *)
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
{
        for i := 1 to EndOfFile do
            writeln('Linha ',i,' termina na posicao ', BeginningOfLine[i]);
}
        for i := 2 to 4 do
        begin
            Temporary := ParameterVector[i];

(*  Parameter /n<count>. Save it into a integer variable. *)
(*  Parameter /o<file>. Save it into a string variable. *)
(*  Parameter /r. Save it into a boolean variable. *)

            case Temporary[2] of
                'H': ShufHelp;
                'N': begin
                        TemporaryNumber := copy (Temporary, 3, length(Temporary));
                        Val(TemporaryNumber, RandomLines, ValReturn);
                    end;
                'O': OutputFileName := copy (Temporary, 3, length(Temporary));
                'R': RepeatedLines := true;
                'V': ShufVersion;
            end;
        end;

(*  If OutputFileName has something, then we should open a second file for
*   output. *)

        If OutputFileName <> '' then
        begin
            writeln('Abriu arquivo: ', OutputFileName);
            hOutputFileName := FileOpen (OutputFileName, 'w');

(*  If there is any problem regarding the opening process, show the error code. *)
            if (hOutputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);
        end;

(*  Show specific number of lines, defined by RandomLines. *)

writeln('Inicio: ');
readln(i);
writeln('Fim: ');
readln(j);

for counter := i to j do
begin
    ReadLineFromFile (counter, PositionsInOutputString, OutputString);
{
    OutputString[BeginningOfLine[counter] - 1] := chr(10);
    OutputString[BeginningOfLine[counter]] := chr(13);
}
    j := 0;
    fillchar(PrintString, sizeof(PrintString), ' ' );
    for j := 0 to PositionsInOutputString do
    begin
{
         writeln('OutputString[',j,']=', OutputString[j]);
}
        PrintString[j] := OutputString[j];
    end;
    PrintString[0] := chr(PositionsInOutputString);
    writeln;
    writeln;
    writeln;
    writeln('PrintString: ' , PrintString);
end;

exit;

{
         If RandomLines > 0 then
            for i := 1 to RandomLines do
            begin
                repeat
                    k := random(EndOfFile);
                until k <> 0; 
                ReadLineFromFile (k, PositionsInOutputString , OutputString);
                OutputString[BeginningOfLine[k] - 1] := chr(10);
                OutputString[BeginningOfLine[k]] := chr(13);
                for j := 1 to BeginningOfLine[k] do
                    write(OutputString[j]);
            end;
}

(*  Closing file. *)
        
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        If OutputFileName <> '' then
            if (not FileClose(hOutputFileName)) then ErrorCode(true);
    end;
end.
