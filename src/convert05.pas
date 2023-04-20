program Convert05;
{$H+}
(* Copyright (C) 1994-2005  jo@magnus.de
   This library is free software; you can redistribute it and/or modify it 
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or 
	(at your option) any later version.

   This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
	or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public 
	License for more details.

   You should have received a copy of the GNU Lesser General Public License 
	along with this library; if not, write to the Free Software Foundation, 
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
*)


uses
   Classes,SysUtils,OldBayerBaum,BtreeFlex;

type
	TPrg	=	class
					constructor Create(const name:string; var res:integer);
					destructor  Destroy; OVERRIDE;
					procedure	Run;
					
				PRIVATE
					oldBaum	: 	TOldFileBayBaum;
					baum		:	TBayBaum;
					words,
					allwords	:	cardinal;
					
					procedure 	Convert(var akt:TOldVal);
				
				PUBLIC
					property 	Worte:cardinal read words; 
					property 	AlleWorte:cardinal read allwords; 
				end;



constructor TPrg.Create(const name:string; var res:integer);
begin
	inherited Create;
	words:=0; allwords:=0; 
	oldbaum:=TOldFileBayBaum.Create(name,true,res);
	if res<>0 then FAIL;
	baum:=TMemBayBaum.Create(name,67108864,16777216,false,res);
	if res<>0 then FAIL;
end;


destructor TPrg.Destroy;
begin
	inherited Destroy;
	baum.Free;
	oldbaum.Free;
end;


procedure TPrg.Run;
begin
	oldbaum.GetAll(@Convert);
end;

	
procedure TPrg.Convert(var akt:TOldVal);
begin
	if baum.Insert(akt.s,akt.dp) and baum.Update(akt.s,akt.dp,akt.z,0) then begin
		if words mod 5000 = 0 then write(#13,' WORDS:   ',words:10);
	end else 
		writeln('Failed: ',akt.s);
	inc(words); 
	inc(allwords,akt.z);
end;


var
	prg	:	TPrg;
	res	:	integer;
begin
	prg:=TPrg.Create(paramstr(1),res);
	if res=0 then 
		prg.Run 
	else begin
		writeln('RES=',res);
		HALT(1)
	end;
	
	writeln(#13,' WORDS:   ',prg.Worte:10);
	writeln(' ENTRIES: ',prg.AlleWorte:10);
	prg.Free;
end.

