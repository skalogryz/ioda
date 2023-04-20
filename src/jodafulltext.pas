library jodafulltext;

(* Copyright (C) 1994-2004  jo@magnus.de
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

{$H+}

uses CMEM, Classes, Strings, SysUtils, Volltext2, ConfigReader;

const
	VTMAXDBS = 32;
			 
type			
	EConfigError = class(Exception);
	PUV 			 = ^cardinal;
 
var
	vti	: integer;
	vtdbs : array [1 .. VTMAXDBS] of TVolltext;
		  
		  
function jodaOpen(dbname : PChar; ro : integer): integer; cdecl; export;
var
	vtidx, res	: integer;
	db				: string;
	openMode		: TDBMode;
						   
begin
	result:=0;
	vtidx:=1;
	while (vtidx<=VTMAXDBS) and (vtdbs[vtidx]<>nil) do inc(vtidx);
	if vtidx>VTMAXDBS then
		result:=-1
	else begin
		db:=ChangeFileExt(StrPas(dbname),'');
		if ro>0 then openMode:=ReadOnlyDB else openMode:=undefinedOpenMode;
		vtdbs[vtidx]:=TVolltext.Create(db,openMode,res);
		if res<>0 then begin
			result:=-abs(res);
			try
				vtdbs[vtidx].Free
			except
				on E:Exception do ;
			end;
			vtdbs[vtidx]:=nil;
		end else begin
			result:=vtidx;
		end;
	end;
end; { jodaOpen }



function jodaClose(handle : integer): integer; cdecl; export;
begin  
	result:=-1;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			try
				vtdbs[handle].Free;
				vtdbs[handle]:=nil;
				result:=0;
			except
				on E:Exception do result:=-4;
			end;
		end;
	end;
end; { jodaClose }


procedure jodaSortIssues(handle:integer; const issueParams:PChar); cdecl; export;
begin
	if ((handle>0) and (handle<=VTMAXDBS) and (vtdbs[handle]<>NIL)) then 
		vtdbs[handle].SortIssues:=StrPas(issueParams);
end;


function jodaSearch(handle : integer;
						 query, dstart, dend, fileFilter	: PChar;
						 maxHits, sortOrder, bitFilter	: integer;
					    var overflow:integer): integer; cdecl; export;
var
	q  : string;
	ov : boolean;
	   
begin
	result:=-1;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			q:=StrPas(query);
			result:=vtdbs[handle].Suche(q,StrPas(dstart),StrPas(dend),StrPas(fileFilter),maxHits,sortOrder,bitFilter,ov);
			if ov then overflow:=1 else overflow:=0;
		end;
	end;
end; { jodaSearch }



function jodaVLSearch(	  handle						   : integer;
						  query, dstart, dend, fileFilter  : PChar;
						  bitFilter						   : PByte;
						  bitFilterNum, maxHits, sortOrder : integer;
					  var overflow						   : integer): integer; cdecl; export;
var
	q  : string;
	ov : boolean;
	   
begin
	result:=-1;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			q:=StrPas(query);
			result:=vtdbs[handle].vlSuche(q,StrPas(dstart),StrPas(dend),StrPas(fileFilter),bitFilter,bitFilterNum,maxHits,sortOrder,ov);
			if ov then overflow:=1 else overflow:=0;
		end;
	end;
end; { jodaVLSearch }



function jodaGetOneHit(handle, hit, maxlen : integer;
					   	  buffer			       : PChar): integer; cdecl; export;
begin
	result:=-1;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			if (hit<0) then
				result:=-3
			else begin
				StrPCopy(buffer,copy(vtdbs[handle][hit],1,maxlen-1));
				result:=0;
			end;
		end;
	end;
end; { jodaGetOneHit }
	


function jodaGetAllHits(handle, hits, maxlen : integer;
							   buffer				 	: PChar): integer; cdecl; export;
var
	res	: string;
	i	: integer;
	
begin
	result:=-1;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			res:='';
			if hits>1 then
			begin
				for i:=0 to hits-2 do
				begin
					if vtdbs[handle][i]<>'' then
						res:=res+vtdbs[handle][i]+#10
					else
						BREAK;
				end;
			end;
			
			if hits>0 then
				res:=res+vtdbs[handle][hits-1];
			StrPCopy(buffer,copy(res,1,maxlen-1));
			result:=length(res);
		end;
	end;
end; { jodaGetAllHits }



function jodaStore(handle : integer;
					    words, fileName, date : PChar;
					    info	       		     : integer;
				       var id		           : cardinal): integer; cdecl; export;
var
	wlist : TStringList;
begin
	result:=0;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			wlist:=TStringList.Create;
			wlist.Sorted:=False;
			wlist.Duplicates:=dupAccept;
			wlist.SetText(words);
			if wlist.Count=0 then
				result:=-100
			else 
				result:=vtdbs[handle].InsertWords(wlist,StrPas(fileName),StrPas(date),'',info,id);
			wlist.Free;
		end;
	end;
end; { jodaStore }



function jodaInvalidateEntry(handle : integer; words: PChar; id : cardinal): integer; cdecl; export;
var
	wlist : TStringList;
begin
	result:=0;
	if (handle>0) and (handle<=VTMAXDBS) then begin
		if vtdbs[handle]=nil then
			result:=-2
		else begin
			wlist:=TStringList.Create;
			wlist.Sorted:=False;
			wlist.Duplicates:=dupAccept;
			wlist.SetText(words);
			if wlist.Count=0 then
				result:=-100
			else
				result:=vtdbs[handle].InvalidateEntry(wlist,id);
			wlist.Free;
		end;
	end;
end;


exports	
	jodaOpen, jodaClose, jodaSearch, jodaVLSearch, jodaGetOneHit, jodaStore, jodaInvalidateEntry;


begin
	for vti:=1 to VTMAXDBS do
		vtdbs[vti]:=nil;
end.
