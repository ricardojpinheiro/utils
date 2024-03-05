program zeroaloc;

{$i d:zeroalo1.pas}

var
    DriveStatus:    TDriveStatus;
    Parameters:     TTinyString;
    i:              byte;
    c:              char;
    j, k, Result:   integer;

procedure CommandLine (KindOf: byte);
(*
*  1 - Version
*  2 - Help
*)

begin
    case KindOf of
        1: begin (* Version *)
                Writeln('                         _            ');
                Writeln(' _______ _ __ ___   __ _| | ___   ___ ');
                Writeln('|_  / _ \ ''__/ _ \ / _` | |/ _ \ / __|');
                Writeln(' / /  __/ | | (_) | (_| | | (_) | (__ ');
                Writeln('/___\___|_|  \___/ \__,_|_|\___/ \___|');
                writeln;
                Writeln('Version 1.0 - Copyright (c) 2024 by');
                Writeln('Brazilian MSX Crew. Some rights');
                Writeln('reserved (not many!).');
                writeln;
                Writeln('This is a improved RALLOC.COM, and we');
                Writeln('hope all useful options are used here.');
                writeln;
                Writeln('It''s licensed under the GPLv3+ license.');
                writeln('Yep, free software. You are free to');
                Writeln('change and redistribute it. But don''t');
                writeln('ask me about any warranties... Use it ');
                writeln('at your own risk. ');
                Writeln('http://gnu.org/licenses/gpl.html');
                writeln;
            end;
        2: begin (* Help *)
                Writeln('Usage: zeroaloc <parameters>');
                Writeln('Get/set reduced allocation info mode.');
                writeln;
                Writeln('Parameters: ');
                writeln('None: Shows current configuration.');
                Writeln('/l <A><+/->...<H><+/-> - Sets drive''s mode:');
                Writeln('Example: A+: Turns on for drive A.');
                Writeln('Example: E-: Turns off for drive E.');
                writeln('/l A+ B-: turns on drive A and turns off drive B.');
                writeln;
                Writeln('/d <n> - Sets each drive''s mode (dec).');
                Writeln('/d 56: Turns on drives C, D, E.');
                writeln;
                Writeln('/b <n> - Sets each drive''s mode (bin).');
                Writeln('/b 11001000: Turns on drives A, B, E.');
                writeln;
                Writeln('/h - Show this help text and exit.');
                Writeln('/v - Show version info and exit.');
                writeln;
            end;
        end;
    halt;
end;

function DOSVEREnhancedDetection: byte;
begin
    FillChar (regs, SizeOf ( regs ), 0 );
    regs.C := ctGetMSXDOSVersionNumber;
    regs.B  := $005A;
    regs.HL := $1234;
    regs.DE := $ABCD;
    regs.IX := $0000;

    MSXBDOS ( regs );
    
    writeln;
    if regs.B < 2 then
        DOSVEREnhancedDetection := 0
    else
        if regs.IX = 0 then
            DOSVEREnhancedDetection := 1
        else
            DOSVEREnhancedDetection := 2;
end;

procedure ShowRALLOCStatus;
begin
    FillChar (DriveStatus, sizeof(DriveStatus), 0);
    
    GetRALLOCStatus (DriveStatus);
    
    writeln('The following drives are in reduced allocation information mode:');
    
    for i := 7 downto 0 do
        if DriveStatus[7 - i] = 1 then
            write (chr((7 - i) + 65), ': ');

    writeln;
end;

BEGIN
(*  Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)

    case DOSVEREnhancedDetection of
        0:  begin
                writeln ('MSX-DOS 1 detected, so zeroaloc won''t run.');
                halt;
            end;
        1:  begin
                writeln ('MSX-DOS 2 detected, so zeroaloc won''t run.');
                halt;
            end;
    end;
    
    if paramcount = 0 then
    (*  Shows current information about zero allocation mode. *)
        ShowRALLOCStatus
    else
    begin
        for i := 1 to paramcount do
        begin
            Parameters := paramstr(i);
                for j := 1 to length(Parameters) do
                    Parameters[j] := upcase(Parameters[j]);

                c := Parameters[2];
                if Parameters[1] = '/' then
                begin
                    delete(Parameters, 1, 2);
                (*  Parameters. *)
                    case c of
                        'V': CommandLine(1);        (* Help     *)
                        'H': CommandLine(2);        (* Version  *)
                        'L':    begin               (* Set using letters. *)
                                    GetRALLOCStatus ( DriveStatus );
                                    
                                    for i := 2 to paramcount do
                                    begin
                                        FillChar ( Parameters, Length(Parameters), chr(32));
                                        Parameters := paramstr(i);

                                        j := 7 - (ord(upcase(Parameters[1])) - 65);
                                        
                                        if Parameters[2] = '+' then
                                            DriveStatus[j] := 1
                                        else
                                            DriveStatus[j] := 0;
                                    end;
                                    SetRALLOCStatus (DriveStatus);
                                end;
                                
                        'D':    begin               (* Set using decimal number. *)
                                    Parameters := paramstr(2);
                                    Val (Parameters, k, Result);
                                    Decimal2Binary (k, DriveStatus);
                                    SetRALLOCStatus (DriveStatus); 
                                end;
                                
                        'B':    begin               (* Set using binary number. *)
                                    Parameters := paramstr(2);
                                    for i := 7 downto 0 do
                                    begin
                                        c := Parameters[i + 1];
                                        Val (c, k, Result);
                                        DriveStatus[7 - i] := k;
                                    end;
                                    SetRALLOCStatus (DriveStatus);
                                end;
                    end;
                end;
        end;
    end;
END.
