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
{$i d:dpb.inc}

Const
    BufferSize = 511;
    MaxLines = 100;

Type
    TParameterVector = array [1..4] of TString;

Var
    MSXDOSversion: TMSXDOSVersion;
    ParameterVector: TParameterVector;
    InputFileName, OutputFileName, Temporary: TFileName;
    TemporaryNumber: string[5];
    hInputFileName, hOutputFileName, nDrive: byte;
    BlockReadResult: byte;
    NewPosition, RandomLines, ValReturn: integer;
    SizeOfInputFile: integer;
    i, j, counter: integer;
    RepeatedLines, UsesOutputFileName, SeekResult: boolean;
    fEOF: boolean;
    dpb: TDPB;
    Registers: TRegs;
    
    Buffer: Array[0..BufferSize] Of Byte;
    Vector: Array[0..MaxLines] of Byte;

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
    
procedure ReadLineFromFile (i: integer; UsesOutputFileName: boolean);
begin
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
    fillchar(InputFileName, sizeof(InputFileName), ' ' );
    fillchar(OutputFileName, sizeof(OutputFileName), ' ' );
    fillchar(TemporaryNumber, sizeof(TemporaryNumber), ' ' );

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
    
    if (GetDPB(nDrive, dpb) = ctError ) then
    begin
        writeln('Error retrieving DPB');
        halt;
    end;

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
    while (fEOF = false) do
    begin
        counter := 0;
        fillchar (Buffer, BufferSize, 0 );

        BlockReadResult := FileBlockRead(hInputFileName, Buffer, BufferSize);
        for i := 0 to BufferSize do
            if Buffer[i] <> 0 then counter := counter + 1;

        i := 1;
        while (i < BufferSize) do
        begin
            if chr(Buffer[i]) = #10 then
            begin
                Vector[j] := i;
                j := j + 1;
            end;
            i := i + 1;
        end;

        if counter = 1 then fEOF := true;
    end;
    Vector[0] := 0;
    for i := 1 to j do
        writeln('Linha ',i,' termina na posicao ', (Vector[i] - Vector[i-1]) - 1);

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

(*  Show specific number of lines, defined by RandomLines. *)

    If RandomLines > 0 then
    begin
        for i := 1 to RandomLines do
        begin
            ReadLineFromFile (i, UsesOutputFileName);
        end;
    end;

(*  If OutputFileName has something, then we should open a second file for
*   output. *)

    If OutputFileName <> ' ' then
    begin
        hOutputFileName := FileOpen (OutputFileName, 'w');

(*  If there is any problem regarding the opening process, show the error code. *)
        if (hOutputFileName in [ctInvalidFileHandle, ctInvalidOpenMode]) then ErrorCode (true);
        
        if (not FileClose(hOutputFileName)) then ErrorCode(true);
    end;


(**)

(*  Closing file. *)

        if (not FileClose(hInputFileName)) then ErrorCode(true);
    
    end;
end.

