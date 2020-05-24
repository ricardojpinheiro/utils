program pwd;

{
* Little program, only shows you which directory you are.
}

{$i d:types.inc}
{$i d:dos.inc}
{$i d:dos2err.inc}

Var
    MSXIOResult: byte;
    MSXDOSversion: TMSXDOSVersion;

Function GetCurrentDrive: byte;
 Var drv :byte;
 Begin
   Inline ( $0e/$19/
            $cd/$05/$00/
            $32/drv
          );
   GetCurrentDrive := drv;
 End;


Function GetCurrentDirectory (Drive: byte): TString;
Type
    TPathBuffer = array[0..63] Of char;
Var
    drv: byte;
    Buf: TPathBuffer;
    St: TString;
    i: byte;
    
Begin
    drv := Drive;
    Inline( $0E/$59/          {Ld c, getdir}
            $3A/ drv /        {Ld a,drive}
            $47/              {Ld b,a }
            $11/ Buf/         {Ld de,bufferadr}
            $CD/$05/$00/      {call bdos}
            $32/MSXIOResult   {ld (doserror),a}
            );
    i := 0; 
    St :='';
    While Buf[i] <> Chr(0) Do
    Begin
        St := St + Buf[i];
        i := i +1;
    End;
    If MsxIOResult = 0 Then
        GetCurrentDirectory := St
    Else
        GetCurrentDirectory := '';
 End;

begin
    GetMSXDOSVersion (MSXDOSversion);

    if (MSXDOSversion.nKernelMajor < 2) then
    begin
        writeln('MSX-DOS 1.x not supported.');
        exit;
    end
    else 
        writeln(concat(chr(GetCurrentDrive + 65), ':\', GetCurrentDirectory(GetCurrentDrive)));
end.
