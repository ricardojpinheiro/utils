{
   sleep.pas
}


program sleep;

type
    TString = string[255];

{$i d:types.inc}
{$i d:fastwrit.inc}
{$i d:dos.inc}
{$i d:dostime.inc}

var i: byte;
    InitialDate, FInalDate: TDate;

(*  Command help.*)

procedure SleepHelp;
begin
    clrscr;
    fastwriteln('Usage: sleep <number><suffix>.');
    fastwriteln('Delay for a specified amount of time.');
    writeln;
    fastwriteln('Description: ');
    fastwriteln('Pause for NUMBER seconds. SUFFIX may be');
    fastwriteln('"s" for seconds (the default), "m" for ');
    fastwriteln('minutes, "h" for hours or "d" for days.');
    fastwriteln('NUMBER need not be an integer. Given ');
    fastwriteln('two or more arguments, pause for the ');
    fastwriteln('amount of time specified by the sum of ');
    fastwriteln('their values.');
    writeln;
    fastwriteln('Parameters: ');
    fastwriteln('/d - Display .');
    fastwriteln('/h - Display this help and exit.');
    fastwriteln('/v - Output version information & exit.');
    writeln;
    halt;
end;

(*  Command version.*)

procedure SleepVersion;
begin
    clrscr;
    fastwriteln('sleep version 1.0'); 
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

BEGIN
    GetMSXDOSVersion (version);

    if (version.nKernelMajor < 2) then
    begin
        fastwriteln('MSX-DOS 1.x not supported.');
        exit;
    end
    else
    begin
        if paramcount = 0 then
            SleepHelp
        else
        begin
            DosGetDate (InitialDate);

{
             Date.nDay := Day;
                    Date.nMonth := Month;
                    Date.nYear := Year;
}
        end;
        
        
        
    end;
END.

