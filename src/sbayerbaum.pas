UNIT SBayerBaum;
{$H-}

(*
	Ableitungungen der Bayerbaum-Klasse mit Streams zum Lesen und Schreiben der Daten.
	Fehlernummern 200-299 
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


INTERFACE
uses
	Classes,SysUtils,JStreams,BayerBaum;

type
	TFileBayBaum=	class(TBayBaum)
							constructor Create(const name:string; readOnly:boolean; var res:integer);
							destructor  Destroy; OVERRIDE;
							procedure   Commit; OVERRIDE;

							function    GetElem(var el:TNode;id:cardinal):boolean; OVERRIDE;
							function    SetElem(var el:TNode;id:cardinal):boolean; OVERRIDE;
							
							PROTECTED
							elStream	:	TStream;
							myFileName	:	string;
							ro			:	boolean;
					end;
						
	TMemBayBaum=class(TFileBayBaum)		// sic! auf TFileBayBaum aufgesetzt
							constructor Create(const name:string; initSize,growSize:longint; readOnly:boolean; var res:integer);
							destructor  Destroy; OVERRIDE;
							procedure   Commit; OVERRIDE;
							procedure   Clear;  OVERRIDE;
					end;
	

IMPLEMENTATION
type
	EFWrongFileType	=	class(Exception);


// Bayerbaum auf der Festplatte

constructor TFileBayBaum.Create(const name:string; readOnly:boolean; var res:integer);
var
	root	:	PNode;
begin
	inherited Create;
	res:=0; elStream:=NIL; root:=NIL; myFileName:=name+'.bay'; 
	ro:=readOnly; 

	try
		new(root);
		if FileExists(myFileName) then
		begin
			if readOnly then 
				elStream:=TFileStream.Create(myFileName,fmOpenRead)
			else
				elStream:=TFileStream.Create(myFileName,fmOpenReadWrite)
		end else
		begin
			if readOnly then raise EFWrongFileType.Create('Falscher Dateityp');
			elStream:=TFileStream.Create(myFileName,fmCreate);
			fillDWord(root^,sizeof(TNode) shr 2,0);
			root^.key:=rootpos;
			SetElem(root^,rootpos);
		end;

		if elStream.size>=rootpos-1+sizeof(TNode) then
		begin
			elStream.Seek(rootpos-1,soFromBeginning);
			elStream.Read(root^,sizeof(TNode));
			wordCounter := root^.wordCounter;
			nodeCounter := root^.nodeCounter;
			allCounter	:= root^.allCounter;
			top			:= elStream.Size+1;
		end;

	except
		on EOutOfMemory  do res:=201;
		on EFWrongFileType do res:=202;
		on EFCreateError do res:=203;
		on EFOpenError do res:=204;
		on EStreamError do res:=205;
	end;

	if root<>NIL then dispose(root);
end;


destructor TFileBayBaum.Destroy;
begin
	if (elStream<>NIL) and (elStream is TFileStream) then Commit;	// sonst erledigt das der Nachfolger
	elStream.Free;
	inherited Destroy
end;


procedure TFileBayBaum.Commit;
var
	el	:	PNode;
begin 
	if ro or (elStream=NIL) then EXIT;
	try 
		new(el); 
		if GetElem(el^,rootpos) then SetElem(el^,rootpos);	// counter in ROOT schreiben
		dispose(el);
	except 
		on EOutOfMemory do bayError:=-201;
	end;
end;


function TFileBayBaum.GetElem(var el:TNode;id:cardinal):boolean;
begin
	result:=true;
	if id=0 then
	begin
		result:=false;
		fillchar(el,sizeof(TNode),0)
	end else 
	begin
		try
			elStream.Seek(id-1,soFromBeginning);
			result:=elStream.Read(el,sizeof(TNode))=sizeof(TNode);
		except
			on EStreamError do 
			begin
				result:=false;
				bayError:=206; EXIT
			end;
		end;
	end;
end;


function TFileBayBaum.SetElem(var el:TNode;id:cardinal):boolean;
begin
	if id>0 then
	begin
		if id=rootpos then
		begin
			el.allCounter 	:= allCounter;
			el.wordCounter := wordCounter;
			el.nodeCounter := nodeCounter; 				//	aktuelle Zähler in root eintragen
		end;
		try
			elStream.Seek(id-1,soFromBeginning);
			elStream.Write(el,sizeof(TNode));
		except
			on EStreamError do 
			begin
				result:=false;
				bayError:=207; EXIT
			end;			
		end;
		result:=true
	end else
		result:=false;
end;



// Bayerbaum im Speicher

constructor TMemBayBaum.Create(const name:string; initSize,growSize:longint; readOnly:boolean; var res:integer);
begin
	inherited Create(name,readOnly,res);
	if res<>0 then EXIT;
	elStream.Free;							// TFileStream freigeben
	elStream:=TLargeMemoryStream.Create(0,growSize);	// als TLargeMemorystream neu anlegen
	with elStream as TLargeMemoryStream do LoadFromFile(myFileName);
	if (initSize>0) and (not ro) then with elStream as TLargeMemoryStream do SetSize(initSize); // erst hier sinnvoll, weil LoadFromFile die Capacity einstellt
end;


destructor TMemBayBaum.Destroy;
begin
	Commit;
	inherited Destroy;
end;


procedure TMemBayBaum.Clear;
var
	root	:	PNode;
begin
	with elStream as TLargeMemoryStream do Clear;
	try
		new(root);
		fillDWord(root^,sizeof(TNode) shr 2,0);
		root^.key:=rootpos;
		SetElem(root^,rootpos);
		dispose(root);
	except
		on EOutOfMemory  do ;
	end;
end;


procedure TMemBayBaum.Commit;
var
	store	:	TFileStream;
begin
	if ro or (elStream=NIL) then EXIT;
	inherited Commit;
	elStream.Seek(0,soFromBeginning);
	store:=TFileStream.Create(myFileName,fmCreate);
	store.CopyFrom(elStream,top-1);
	store.Free;
end;


end.
