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
    TotalBufferSize = 2047;
    BufferSize = 511;
    MaxLines = 250;

Type
    TParameterVector = array [1..4] of TString;
    TOutputString = array[0..255] of char;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName, OutputFileName, Temporary: TFileName;
    TemporaryNumber: string[5];
    hInputFileName, hOutputFileName, nDrive: byte;
    BlockReadResult: byte;
    NewPosition, RandomLines, ValReturn: integer;
    SizeOfInputFile, EndOfFile: integer;
    i, j, k, counter: integer;
    Character: char;
    RepeatedLines, UsesOutputFileName, SeekResult: boolean;
    fEOF: boolean;
    Registers: TRegs;
    
    Buffer: Array[1..2, 0..TotalBufferSize] Of Byte;
    LineLength: Array[0..MaxLines] of Integer;
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

(*  Reads a random line from a file. If UsesOutputFileName is true, then
    it will be send to a output file. *)
    
procedure ReadLineFromFile (Line: integer; EndOfFile: integer; var OutputString: TOutputString);
var
    TemporaryReal: real;
    Beginning, Finish, InitialBlock, FinalBlock: integer;
    j, k, l: integer;
   
begin
    TemporaryReal := 0.0;

(*  Move seek pointer to the beginning of the file. *)

    SeekResult := FileSeek( hInputFileName, 0, ctSeekSet, NewPosition );

(*  Several calculations to know which block is it. *)

    for j := 0 to Line - 1 do
        TemporaryReal := TemporaryReal + LineLength[j];
    
    
    
    Beginning := round(int(TemporaryReal));
    InitialBlock := round(int(Beginning / (BufferSize + 1)));
    Finish := Beginning + LineLength[Line];
    FinalBlock := Finish div (BufferSize + 1);

    writeln('Temp: ', TemporaryReal:2:0, ' Bloco inicial: ', InitialBlock, ' Bloco final: ', FinalBlock,
     ' Linha: ', Line, ' Beginning: ', Beginning, ' Finish: ', Finish);

(*  Move to the InitialBlock-th position. *)

    for j := 1 to InitialBlock do
        If (not FileSeek (hInputFileName, BufferSize, ctSeekCur, NewPosition)) then
            ErrorCode(true);

(*  Read the k and k+1 blocks. *)

    for i := 1 to 2 do
    begin
        fillchar (Buffer[i], TotalBufferSize, 0);

        BlockReadResult := FileBlockRead(hInputFileName, Buffer[i], BufferSize);
        if (BlockReadResult = ctReadWriteError) then
            ErrorCode(true);

        for j := 1 to BufferSize do
            if (Buffer[i,j] = ord(10)) or (Buffer[i,j] = ord(13)) then
                Buffer[i,j] := ord(255);

    end;
    
    fillchar(OutputString, sizeof(OutputString), ' ' );
{
    for i := 1 to 2 do
    begin
        writeln('i: ', i);
        for j := 0 to 511 do
            write(chr(Buffer[i,j]));
        writeln;
    end;
    
exit;
    for j := 0 to Line - 1 do
        TemporaryReal := TemporaryReal + LineLength[j];
    
    Beginning := round(int(TemporaryReal));
    InitialBlock := round(int(Beginning / (BufferSize + 1)));
    Finish := Beginning + LineLength[Line];
    FinalBlock := Finish div (BufferSize + 1);
}
    i := 1;
    j := Beginning;
    k := 1;
    l := (Beginning mod (BufferSize + 1)) - (Line - 1);
    
    while (j < Finish - 2) do
    begin
        OutputString[k] := chr(Buffer[i,l]);
        if (l = BufferSize - 1) then
        begin
            i := i + 1;
            l := 0;
        end;

        writeln('OutputString[',k,']=', OutputString[k], ' Buffer[', i, ',', l, ']=', chr(Buffer[i,l]), ' ');
{
        write(chr(Buffer[i,l]));

        write(OutputString[k]);
}        
        j := j + 1;
        k := k + 1;
        l := l + 1;
    end;
end;

(*  Command help.*)

procedure ShufHelp;
begin
    clrscr;
    fastwriteln(' Usage: shuf <file> <parameters>.');
    fastwriteln(' Write a random permutation of the input lines to standard output.');
    writeln;
    fastwriteln(' File: Text file from where we are getting lines.');
    writeln;
    fastwriteln(' Parameters: ');
    fastwriteln(' /h - Display this help and exit.');
    fastwriteln(' /n<COUNT> - Output at most COUNT lines.');
    fastwriteln(' /o<FILE>  - Write result to FILE instead of standard output.');
    fastwriteln(' /r - Output lines can be repeated.');
    fastwriteln(' /v - Output version information and exit.');
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

            i := 1;
            while (i <= BufferSize) do
            begin
                Character := chr(Buffer[1,i]);
                if Character = #13 then
                begin
                    LineLength[j] := k + 1;
                    j := j + 1;
                    k := 0;
                end;
                i := i + 1;
                k := k + 1;
            end;

            if counter = 1 then fEOF := true;

        end;
        LineLength[0] := 0;
        LineLength[1] := LineLength[1] + 2;
        LineLength[EndOfFile] := LineLength[EndOfFile] - 1;
        EndOfFile := j - 1;

        for i := 1 to EndOfFile do
            writeln('Linha ',i,' termina na posicao ', LineLength[i]);

exit;

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

        for k := i to j do
        begin
            ReadLineFromFile (k, EndOfFile, OutputString);
{
             for i := 1 to 80 do
                write(OutputString[i]);
}
        end;

exit;

        If RandomLines > 0 then
            for i := 1 to RandomLines do
            begin
                repeat
                    k := random(EndOfFile);
                until k <> 0; 
                writeln('Linha: ', k);
                ReadLineFromFile (k, EndOfFile, OutputString);
                 for j := 1 to SizeOf(OutputString) do
                    write(OutputString[j]);
                writeln;

            end;

(*  Closing file. *)
        
        if (not FileClose(hInputFileName)) then ErrorCode(true);
        If OutputFileName <> '' then
            if (not FileClose(hOutputFileName)) then ErrorCode(true);
    end;
end.
