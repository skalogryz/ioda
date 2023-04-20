UNIT FileRefs;
(* 
	stellt ein Hilfsobjekt für das Volltextobjekt zur Verfügung.
	Es verwaltet die Tabelle ID => Dateiname (TDynamicFileRef).
	Es können mehrere Dateien gleichen Inhalts ("Doubletten") verkettet 
	werden, damit sie nicht mehrfach indiziert werden müssen.
	
	Fehlernummern 400-499
	
	Ursprüngliche Version (Delphi-1, feste Längen) jo 4/95
	komplett überarbeitet und portiert nach Linux-fp jo 6/01	
*)

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
INTERFACE
uses
	classes,sysutils,JStrings;

type
	CFileRef		=	class of TFileRef;
	TFileRef=	class
{$WARNINGS OFF}
						constructor Create(const name:string; readOnly:boolean; var res:integer); VIRTUAL;
{$WARNINGS ON}
						destructor  Destroy; OVERRIDE;
						function    NewFilename(const name,info:string; var id:cardinal):integer; VIRTUAL; ABSTRACT;
						function 	ChainFilename(const name: string; lastId:cardinal; var id:cardinal):integer; VIRTUAL; ABSTRACT;
						function		InvalidateFilename(id:cardinal):integer; VIRTUAL; ABSTRACT;
						procedure	Commit; VIRTUAL;
						procedure   Clear; VIRTUAL;
						
						PROTECTED
						refStream:	TStream;
						myFileName,
						aktName,
						aktTitel	:	string;
						aktID,
						aktPtr	:	cardinal;
						frError	:	integer;
						ro			:	boolean;
						
						function		TellError:integer;
						function		NextRefID:cardinal; VIRTUAL; ABSTRACT;
						function    GetFilename(id:cardinal):string; VIRTUAL; ABSTRACT;
						function    GetTitel(id:cardinal):string; VIRTUAL; ABSTRACT;
						function		ReadRecord(id:cardinal):integer; VIRTUAL; ABSTRACT;
												
						PUBLIC
						property    Error:integer read TellError;
						property		NextID:cardinal read NextRefID;
						property    filename[i:cardinal]:string read GetFilename; DEFAULT;
						property    titel[i:cardinal]:string read GetTitel;
					end;

	TDynamicFileRef=class(TFileRef)
						constructor Create(const name:string; readOnly:boolean; var res:integer); OVERRIDE;
						destructor  Destroy; OVERRIDE;
						function    NewFilename(const name,info:string; var id:cardinal):integer; OVERRIDE;
						function 	ChainFilename(const name: string; lastId:cardinal; var id:cardinal):integer; OVERRIDE;
						function		InvalidateFilename(id:cardinal):integer; OVERRIDE;
						
						PROTECTED
						function		NextRefID:cardinal; OVERRIDE;
						function    GetFilename(id:cardinal):string; OVERRIDE;
						function    GetTitel(id:cardinal):string; OVERRIDE;
						function		ReadRecord(id:cardinal):integer; OVERRIDE;
					end;

	TMemFileRef=class(TDynamicFileRef)	// gleiche Funktionalität, aber im Arbeitsspeicher
						constructor Create(const name:string; readOnly:boolean; var res:integer); OVERRIDE;
						destructor 	Destroy; OVERRIDE;
						procedure 	Commit; OVERRIDE;
						procedure   Clear;  OVERRIDE;
					end;


IMPLEMENTATION
const
	align		=	4;		// Rundung der IDs auf DWord-Grenze / ID*rund=Filepos

type
	EFWrongFileType=	class(Exception);
	

// Abstrakter Vorfahre

constructor TFileRef.Create(const name:string; readOnly:boolean; var res:integer);
const
	s	:	string[31]	=	'(c) jo@magnus.de 2001';
begin
	inherited Create;
	res:=0; aktName:=''; aktTitel:=''; aktPtr:=0;
	refStream:=NIL; myFileName:=name+'.ref'; ro:=readOnly; 

	try
		if FileExists(myFileName) then
		begin
			if readOnly then 
				refStream:=TFileStream.Create(myFileName,fmOpenRead)
			else
				refStream:=TFileStream.Create(myFileName,fmOpenReadWrite);
		end else
		begin
			if readOnly then raise EFWrongFileType.Create('Datei nicht vorhanden');
			refStream:=TFileStream.Create(myFileName,fmCreate);
			refStream.Write(s[1],length(s));		//	erste id darf nicht null sein
		end;

	except
		on EFWrongFileType do res:=401;
		on EFCreateError do res:=402;
		on EFOpenError do res:=403;
		on EStreamError do res:=404;
	end
end;


destructor TFileRef.Destroy;
begin
	refStream.Free;
	inherited Destroy;
end;


procedure TFileRef.Commit;
begin end;


procedure TFileRef.Clear;
begin end;


function TFileRef.TellError:integer;
begin
	result:=frError; frError:=0;
end;


// Aktuelle FileRef-Klasse

constructor TDynamicFileRef.Create(const name:string; readOnly:boolean; var res:integer);
begin
	inherited Create(name,readOnly,res);
end;


destructor TDynamicFileRef.Destroy;
begin
	inherited Destroy;
end;


function TDynamicFileRef.NextRefID:cardinal;
begin
	result:=(refStream.Size + align-1) div align;
end;


function TDynamicFileRef.NewFilename(const name,info:string; var id:cardinal):integer;
begin
	id:=NextRefID;
	try
		refStream.Seek(id*align,soFromBeginning);
		refStream.WriteDWord(0);					// Verkettung auf Null setzen
		refStream.WriteAnsiString(name);
		refStream.WriteAnsiString(info);
		result:=0;
	except
		on EStreamError do result:=-404;
	end;
end;



function TDynamicFileRef.ChainFilename(const name: string; lastId:cardinal; var id:cardinal):integer;
begin
	if lastID=0 then
	begin
		result:=-406; EXIT
	end;
 	result:=NewFilename(name,'',id);
  	if result=0 then
 	try
		refStream.Seek(lastId*align,soFromBeginning);
		refStream.WriteDWord(id);					// Verkettung aktualisieren
	except
		on EStreamError do result:=-404;
	end;
end;


function TDynamicFileRef.InvalidateFilename(id:cardinal):integer;
begin
	if (id=0) or (id>=NextRefID) then
	begin
		result:=-407; EXIT
	end;

	try
		refStream.Seek(id*align,soFromBeginning);
		refStream.WriteDWord(0);					// Verkettung (falls vorhanden) auf Null setzen
		refStream.WriteAnsiString('');
		refStream.WriteAnsiString('');
		result:=0;
	except
		on EStreamError do result:=-408;
	end;
end;


function TDynamicFileRef.ReadRecord(id:cardinal):integer;
var
	s	:	string;
begin
	result:=0; 
	if id=aktID then EXIT;

  	try
		refStream.Seek(id*align,soFromBeginning);
		aktPtr:=refStream.ReadDWord;
		aktName:=refStream.ReadAnsiString;
		if aktName<>'' then s:=refStream.ReadAnsiString else s:='';
		if s<>'' then aktTitel:=s;					// nur bei der Wurzel eingetragen (sonst leer)
		aktID:=id;
	except
//		on E:Exception do writeln('EX=',E.message,' id=',id);
		on EStreamError do result:=-404
		else result:=-405;
	end;
end;


function TDynamicFileRef.GetFilename(id:cardinal):string;
var
	res	:	integer;
begin
	if id>0 then
		res:=ReadRecord(id)
	else
	begin
		if aktPtr=0 then 		// no more files...
		begin
			result:=''; res:=0; EXIT
		end;
		res:=ReadRecord(aktPtr);
	end;

	if res=0 then 
		result:=aktName 
	else 
	begin
		result:='';
		frError:=res;
	end;
end;


function TDynamicFileRef.GetTitel(id:cardinal):string;
var
	res	:	integer;
begin
	res:=ReadRecord(id);
	if res=0 then 
		result:=aktTitel 
	else 
	begin
		result:='';
		frError:=res;
	end;
end;


// Dynamische Dateiliste im Speicher

constructor TMemFileref.Create(const name:string; readOnly:boolean; var res:integer);
begin
	inherited Create(name,readOnly,res);
	if res<>0 then EXIT;
	refStream.Free;							// TFileStream freigeben
	refStream:=TMemoryStream.Create;
	with refStream as TMemoryStream do LoadFromFile(myFileName);
end;


destructor TMemFileref.Destroy;
begin
	Commit;
	inherited Destroy;
end;


procedure TMemFileref.Commit;
var
	store	:	TFileStream;
begin
	if ro then EXIT;
	refStream.Seek(0,soFromBeginning);
	store:=TFileStream.Create(myFileName,fmCreate);
	store.CopyFrom(refStream,refStream.Size);
	store.Free;
end;


procedure TMemFileRef.Clear;
begin
	with refStream as TMemoryStream do Clear;
end;


end.
