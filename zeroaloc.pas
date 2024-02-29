program zeroaloc;

{$i d:types.pas}
{$i d:msxdos.pas}
{$i d:msxdos2.pas}
{$i d:nextor.pas}

var
	DriveStatus: 	TDriveStatus;
	Status: 		TTinyString;
	Parameters:		TTinyString;
	i, j:			byte;
	c:				char;

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
                Writeln('Version 0.1 - Copyright (c) 2024 Brazilian MSX Crew.');
                Writeln('Some rights reserved (not many!).');
                writeln;
                Writeln('This is a utility which is a improved RALLOC.COM.	');
                Writeln('And we hope all useful options are used here.		');
                writeln;
                Writeln('It''s licensed under the GPLv3+ license. Yep, free software. You are free');
                Writeln('to change and redistribute it. But don''t ask me about any warranties...');
                Writeln('Use it at your own risk. http://gnu.org/licenses/gpl.html');
                writeln;
            end;
        2: begin (* Help *)
                Writeln('Usage: zeroaloc <parameters>');
                Writeln('Utility for Nextor that get/set reduced allocation information mode.');
                writeln;
                writeln('If you run without any parameters, it shows current configuration.');
                writeln;
                Writeln('Parameters: ');
				Writeln('/l <A><mode> ... <H><mode>	- Sets each drive''s mode, where:');
				Writeln('Example: A+: Turns on zero allocation information for drive A.');
				Writeln('Example: E-: Turns off zero allocation information for drive E.');
				writeln('So... /l A+ B- E+ H- turns on drives A and E, and turns off drives B and H.');
                writeln;
                Writeln('/d <number>	- Sets each drive''s mode, using a decimal number.');
                Writeln('Example: /d 244: Turns on for drives A, B, C, D and F.');
                writeln;
                Writeln('/b <number>	- Sets each drive''s mode, using a binary number.');
                Writeln('Example: /b 11100100: Turns on for drives A, B, C and F.');
				writeln;
                Writeln('/h		- Show this help text and exit.');
                Writeln('/v		- Output version information and exit.');
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
	FillChar (Status, sizeof(Status), chr(32));
	
	GetRALLOCStatus (DriveStatus);
	
	writeln('The following drives are in reduced allocation information mode:');
	
	for i := 0 to 7 do
		if DriveStatus[i] = 1 then
			write (chr(i + 65), ': ');

	writeln;
end;

procedure DefineRALLOCStatus (KindOf: byte);
begin
end;

BEGIN
(*	Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)

	case DOSVEREnhancedDetection of
		0: 	begin
				writeln ('MSX-DOS 1 detected. ZEROALOC won''t run. Sorry.');
				halt;
			end;
		1:  begin
				writeln ('MSX-DOS 2 detected. ZEROALOC won''t run. Sorry.');
				halt;
			end;
	end;
	
	if paramcount = 0 then
	(*	Shows current information about zero allocation mode. *)
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
						'V': CommandLine(1);		(* Help 	*)
						'H': CommandLine(2);		(* Version 	*)
						'L': 	begin				(* Set using letters. *)
									DefineRALLOCStatus (1);
								end;
						'D': 	begin				(* Set using decimal number. *)
									DefineRALLOCStatus (2);
								end;
						'B': 	begin				(* Set using binary number. *)
									DefineRALLOCStatus (3);
								end;
					end;
				end;
		end;
	end;
END.
