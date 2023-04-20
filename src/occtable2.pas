UNIT OccTable2;
{ 
	stellt ein Hilfsobjekt für das Volltextobjekt zur Verfügung.
	Zusammen mit einem Bayerbaum eingesetzt, speichert es alle Vorkommen eines	Strings.
	
	Fehlernummern 300-399
	jo 4/95, portiert nach Linux-fp 6/01, völlig neu gefasst 5/04	
}

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

{$H-}
INTERFACE
uses
	classes,sysUtils,JStreams,JStrings,IDList;
	
const
	defCluster	=	2;    		               // min. Voll-Einträge/Cluster
	startContReadLen	= 512; 		   			// Anzahl Byte pro weiterem Lesezugriff (erster Zugriff siehe Constructor 'def1stReadLen')
	maxCluster	= 8192;                       // max. Voll-Einträge/Cluster
	largestOccLen=12;									// derzeit maximal 12-Byte OccLen
	maxClusterLen=maxCluster*largestOccLen;	// größtmögliche Clusterlänger in Byte
	cluDaLen	:	array[boolean] of cardinal = (4,8);
	escMask	:	array[boolean] of cardinal = ($C0000000,$40000000);

type
{ Bedeutung der Bits 31 und 30: 
		erstes DWord in der ersten und zweiten (nicht dritten!) Variante des Records "TOccl":
			01: ID, 
			10: in erster ID = full flag (ergibt zusammen mit ID-Flag => 11), 
			10: an Stelle einer nachfolgenden ID: len flag (bleibt 10)
		im Gewicht:
			10: last flag 

		Cluster können zwei Zustände haben:
			In VOLLEN Clustern ist das full flag (11 bei erster ID) und das last flag (letztes Gewicht) gesetzt,
			SONST ist das len-Flag (am Beginn des freien Platzes) gesetzt.
			Bei leer gelöschten Clustern ist das len Flag am Anfang des RecordArrays mit 10 geflaggt
			
}
	occElType 	= (OID,ODATA,OMOREDATA,OLEN);
	TOccEl =	packed record
		case occElType of								
		   OID	:     (id		:  cardinal);  //  0-3FFFFFFh (1G)
		   ODATA :     (pos		:	word;
							 info,
		   			    gewicht	:  byte); 		//  0-3F 		(64)
		   OMOREDATA:  (datum,
		   			    moreInfo:  word);
		   OLEN  :     (clen 	:  cardinal);
	end;
	POccEl = ^TOccEl;
	
	TOccA = array[0..maxCluster-1] of TOccEl;
	POccA = ^TOcca;

	TOccFirstCluster = packed record
		last,
		next	:	cardinal;
		occs	:	ToccA					// dynamische Länge
	end;
	POccFirstCluster = ^TOccFirstCluster;
	
	TOccNextCluster =	packed record
		next	:	cardinal;
		occs	:	ToccA					// dynamische Länge
	end;
	POccNextCluster = ^TOccNextCluster;

	TTraverse 	=	procedure(elID,elPos,elDat,elWeight,elInf:cardinal) of object;

//	CClusterMaster	=	class of TClusterMaster;
	TClusterMaster	=	class
		class function CheckoutType(name:string; var size:longint):integer;
		class function Open(name:string; elSize,initSize,growSize:longint; readOnly,enableRecycling:boolean; var res:integer):TClusterMaster;
		constructor Create(const name:string; elSize:longint; readOnly,enableRecycling:boolean; var res:integer);
		destructor  Destroy; OVERRIDE;
		function    InsertRecord(var key:cardinal; size,elID,elPos,elDate,elWeight,elInfo:cardinal):integer; VIRTUAL; ABSTRACT;
		function    GetItemList(key:cardinal; callback:TTraverse; countOnly:boolean):longint; VIRTUAL; ABSTRACT;
		function 	GetItemCount(key:cardinal):longint; VIRTUAL;
		function 	InvalidateRecord(key,fid:cardinal):longint; VIRTUAL; ABSTRACT;
		procedure   Commit; VIRTUAL; 
		procedure   Clear; VIRTUAL; 

		PROTECTED
		firstOcc		:	POccFirstCluster;
		occ,tmpOcc	:	POccNextCluster;
		firstOccSize,
		occSize,
		nextKey,
		occLen,
		fullClusterLen,
		def1stReadLen,
		defContReadLen,
		lenCount,
		dataSum		:	cardinal;
		occStream	:	TStream;
		resList		:	TDWList;
		myFileName	:	string;
		ro,
		recycling	:	boolean;

		function		GetResult(i:integer):TDW;
		function 	GetCount:integer;
		procedure	GetData(p:PByte; var r:cardinal);
		procedure  	GetItem(p:PByte; var last:boolean; var i,r,id:cardinal; callback:TTraverse);
		procedure 	SetContReadLen(len:cardinal);
		procedure 	CallbackNOP(elID,elPos,elDat,elWeight,elInf:cardinal); // Beispiel eines Callbacks
		
		PUBLIC
		property		Results[i:integer]:TDW read GetResult; DEFAULT;
		//				^^ wenn "caller" der letzten GetItemlist-Operation NIL war
		property		Count:integer read GetCount;
	end;

	TClusterMasterD	=	class(TClusterMaster)
		constructor Create(const name:string; elSize:longint; readOnly,enableRecycling:boolean; var res:integer);
		destructor  Destroy; OVERRIDE;
		function    InsertRecord(var key:cardinal; size,elID,elPos,elDate,elWeight,elInfo:cardinal):integer; OVERRIDE;
		function    GetItemList(key:cardinal; callback:TTraverse; countOnly:boolean):longint; OVERRIDE;
		function 	InvalidateRecord(key,fid:cardinal):longint; OVERRIDE;
		
		PROTECTED
		function    NewCluster(size:cardinal; first:boolean):cardinal; VIRTUAL;
	end;

	TClusterMasterM	=	class(TClusterMasterD)
		constructor Create(const name:string; elSize,initSize,growSize:longint; readOnly,enableRecycling:boolean; var res:integer);
		destructor  Destroy; OVERRIDE;
		procedure   Commit; OVERRIDE;
		procedure   Clear;  OVERRIDE;
	end;


IMPLEMENTATION
type
	EFWrongFileType=	class(Exception);


// Klassenmethoden:

class function TClusterMaster.CheckoutType(name:string; var size:longint):integer;
var
	occStream_	:	TStream;
begin
	result:=0; size:=0;
	if FileExists(name+'.ocl') then begin
		try
			occStream_:=TFileStream.Create(name+'.ocl',fmOpenRead);
			size:=occStream_.ReadDWord;
			occStream_.Free;
		except
			on EFOpenError  do result:=303;
			on EStreamError do result:=304;
		end;
	end;
end;


class function TClusterMaster.Open(name:string; elSize,initSize,growSize:longint; readOnly,enableRecycling:boolean; var res:integer):TClusterMaster;
var
	size	:	longint;
begin
	res:=301; result:=NIL;
	if FileExists(name+'.ocl') then begin
		res:=CheckoutType(name,size);
		if res<>0 then EXIT;
	end else begin
		if readOnly then EXIT;		// es muss eine neue Datei angelegt werden
		size:=abs(elSize)
	end;
	if elSize>=0 then 
		result:=TClusterMasterD.Create(name,size,readOnly,enableRecycling,res)
	else 
		result:=TClusterMasterM.Create(name,size,initSize,growSize,readOnly,enableRecycling,res);
end;


// abstrakte Klasse:

constructor TClusterMaster.Create(const name:string; elSize:longint; readOnly,enableRecycling:boolean; var res:integer);
begin
	inherited Create;
	occStream:=NIL; resList:=NIL; firstOcc:=NIL; occ:=NIL; tmpOcc:=NIL;
	res:=0; myFileName:=name+'.ocl'; ro:=readOnly;
	try
		if FileExists(myFileName) then begin
			if readOnly then 
				occStream:=TFileStream.Create(myFileName,fmOpenRead)
			else
				occStream:=TFileStream.Create(myFileName,fmOpenReadWrite);
			occLen:=occStream.ReadDWord; 
			nextKey:=occStream.Size;
		end else
		begin
			if readOnly then raise EFWrongFileType.Create('ReadOnly mode requestet - may not create file!');
			occStream:=TFileStream.Create(myFileName,fmCreate);
			occLen:=abs(elSize);
			nextkey:=32;
			occStream.Seek(0,soFromBeginning);
			occStream.WriteDWord(occLen);
		end;
		resList:=TDWList.Create(maxlongint);
		
	except
		on EFWrongFileType do res:=301;
		on EFCreateError do res:=302;
		on EFOpenError do res:=303;
		on EStreamError do res:=304;
	end;
	
	recycling:=enableRecycling; 
	fullClusterLen:=maxCluster*occLen;
	firstOccSize:=8+fullClusterLen;
	occSize:=4+fullClusterLen;
	def1stReadLen:=((512-8) div occLen)*occlen;
	defContReadLen:=startContReadLen;		//	wird im Lauf dynamisch angepasst
	dataSum:=0; lenCount:=0;
	try
		getmem(firstOcc,firstOccSize);
		getmem(occ,occSize);
		getmem(tmpOcc,occSize);
	except
		on EOutOfMemory do
		begin
			if firstOcc<>NIL then freemem(firstOcc,firstOccSize); firstOcc:=NIL;
			if occ<>NIL then freemem(occ,occSize); occ:=NIL;
			res:=-300;
		end;
	end;
end;


destructor TClusterMaster.Destroy;
begin
	freemem(tmpOcc,occSize);
	freemem(occ,occSize);
	freemem(firstOcc,firstOccSize);
	resList.Free;
	occStream.Free;
	inherited Destroy
end;


procedure  TClusterMaster.Commit; 
begin end;


procedure TClusterMaster.Clear;
begin end;


function TClusterMaster.GetResult(i:integer):TDW;
begin
	try	
		if resList=NIL then raise EListError.Create('RESLIST is not initialized (NIL)');
		result:=resList.Element[i];
	except
		on EListError do fillDWord(result,sizeOf(TDW) shr 2,0);
	end;
end;


function TClusterMaster.GetCount:integer;
begin
	try	
		if resList=NIL then raise EListError.Create('RESLIST is not initialized (NIL)');
		result:=resList.Count;
	except
		on EListError do fillDWord(result,sizeOf(TDW) shr 2,0);
	end;
end;


procedure TClusterMaster.GetData(p:PByte; var r:cardinal);
var
	b,n	:	cardinal;
begin
	if (p=NIL) or (r>=fullClusterLen) then EXIT;
	try
		if r+defContReadLen>=fullClusterLen then b:=fullClusterLen-r else b:=defContReadLen;
		p+=r;
		n:=occStream.Read(p^,b);
		r+=n;
	except
		on E:Exception do writeln(' EX=',E.message,' in occtable.GetData');	
	end;
end;


procedure TClusterMaster.GetItem(p:PByte; var last:boolean; var i,r,id:cardinal; callback:TTraverse);
var
	pos,datum,gewicht,info,hiInfo	:	longint;
begin
	last:=true;

	if id=0 then begin
		if i+occLen>r then begin
			GetData(p,r);
			if i+occLen>r then EXIT;				// nicht genug Daten vorhanden
		end;
		id:=POccEl(p+i)^.id and $3FFFFFFF;		// flags ausfiltern
		i+=4;
	end else begin
		if i+occLen-4>r then begin
			GetData(p,r);
			if i+occLen-4>r then EXIT;				// nicht genug Daten vorhanden
		end;
	end;	
	
	pos:= 	 POccEl(p+i)^.pos;
	info:=	 POccEl(p+i)^.info; 
	gewicht:= POccEl(p+i)^.gewicht and $3F;
	last:=	 POccEl(p+i)^.gewicht and $80<>0;
	if occLen>8 then begin
		datum:=POccEl(p+i+4)^.datum;
		if occLen>10 then begin
			hiInfo:=POccEl(p+i+4)^.moreInfo;
			info:=(hiInfo shl 8) or info;
		end;
	end else
		datum:=0;

	if callback<>NIL then 
		Callback(id,pos,datum,gewicht,info)
	else if resList<>NIL then 
		resList.Add([id,pos,datum,gewicht,info]);// wenn weder Callback noch resList definiert sind, wird nur gezählt

	i+=occLen-4;
	if i+4>r then GetData(p,r);
	last:=last or (i+4>r)
end;


procedure TClusterMaster.CallbackNOP(elID,elPos,elDat,elWeight,elInf:cardinal);
begin { nur als Beispiel gedacht }  end;


function TClusterMaster.GetItemCount(key:cardinal):longint;
begin
	resList.Free; resList:=NIL;
	result:=GetItemList(key,NIL,true);
end;


procedure TClusterMaster.SetContReadLen(len:cardinal);	// errechnet durchschnittliche Clustergröße
begin
	inc(lenCount); dataSum+=len; 
	if lenCount mod 100=0 then begin
		defContReadLen:=((dataSum div lenCount) shr 9) shl 9;	// in 512-Byte-Blöcken rechnen
		if defContReadLen<512 then 
			defContReadLen:=512 
		else if defContReadLen>8192 then
			defContReadLen:=8192;

		if dataSum>=$F0000000 then begin
			dataSum:=dataSum shr 8; lenCount:=lenCount shr 8
		end;
	end;
end;


// konkrete Klasse: Datenhaltung auf Disk

constructor TClusterMasterD.Create(const name:string; elSize:longint; readOnly,enableRecycling:boolean; var res:integer);
begin
	inherited Create(name,elSize,readOnly,enableRecycling,res);
	if res<>0 then FAIL;	
end;


destructor TClusterMasterD.Destroy;
begin
	inherited Destroy;
end;


function TClusterMasterD.NewCluster(size:cardinal; first:boolean):cardinal;
begin
	result:=nextKey;
	if first then 
		nextkey+=8+occLen*size
	 else
		nextkey+=4+occLen*size;
end;


function TClusterMasterD.InsertRecord(var key:cardinal; size,elID,elPos,elDate,elWeight,elInfo:cardinal):integer;
var	 														// Result<0 für Fehler, 0 für o.k. 
	idEl,datEl,moreDatEl					:	TOccEl;
	i,j,len,r,lastI,aktKey,tmpKey,
	newKey,dw,nextCluster,id,lastID	:	cardinal;
	p											:	PByte;
	isFull,dirty							:	boolean;

begin
	result:=0; lastI:=0; lastID:=0; dirty:=false;
	size:=size and $3FFF;							// size kann maximal 16383 sein
	// Daten zunächst auf drei Record-Varianten (jeweils DWords) verteilen:
	id:=elID and $3FFFFFFF;							// reine ID 
	idEl.id:=id or $40000000; 						// ID-Flag setzen
	with datEl do begin
		pos   	:= elPos and $FFFF;
		info  	:= elInfo and $FF;
		gewicht	:= (elWeight and $3F);	 		// ID-Flag löschen, full-flag löschen
	end;
	with moreDatEl do begin
		datum		:= elDate and $FFFF;
		moreInfo := (elInfo and $FFFF00) shr 8;
	end;

	if size>maxCluster then	size:=maxCluster else if size=0 then size:=defCluster;
	try
		if key=0 then begin							// FALL 1: neues Wort, Erstcluster anlegen
			key:=NewCluster(size,true);
			if size=1 then begin
				idEl.id:=idEl.id or $80000000;	// full flag setzen 
				datEl.gewicht:=datEl.gewicht or $80; // last-Flag setzen
			end;
			fillWord(firstOcc^,(8+occLen*size) shr 1,0);
			with firstOcc^ do begin
				occs[0]:=idEL;
				occs[1]:=datEl;
				if occLen>8 then occs[2]:=moreDatEl;
				if size>1 then begin
					p:=@occs; 
					PoccEl(p+occLen)^.clen:=size or $80000000;	// len mit len flag setzen
				end;
			end;
			occStream.Seek(key,soFromBeginning);
			occStream.Write(firstOcc^,8+occLen*size);	// neuen Cluster wegen Dateilänge unbedingt komplett abspeichern
			EXIT											// Fall 1 ist fertig
		end;
		occStream.Seek(key,soFromBeginning);
		occStream.Read(firstOcc^,8+def1stReadLen);// zunächst nur maximal 512 Byte lesen

		if firstOcc^.last=0 then with firstOcc^ do begin
			aktKey:=key;
		  	isFull:=occs[0].id and $C0000000=$C0000000; // ID *und* full flag müssen gesetzt sein
			nextCluster:=next;
			p:=@occs;
		end else with occ^ do begin
			aktKey:=firstOcc^.last;					// letzten Knoten laden
			occStream.Seek(aktKey,soFromBeginning);
			occStream.Read(occ^,4+def1stReadLen);// zunächst nur maximal 512 Byte lesen
			isFull:=occs[0].id and $C0000000=$C0000000;
			nextCluster:=next;
			p:=@occs;
		end;
		if not isFull then begin
			len:=0; i:=0; r:=def1stReadLen;		// nach dem Ende des teilvollen Cluster suchen
			while ((len=0) and (i<fullClusterLen)) do begin
				if i+4>r then begin
					GetData(p,r);						//	Daten nachladen
					if i+4>r then begin				// sollte nicht vorkommen: zu wenig Daten vorhanden	
						result:=-305; EXIT
					end;
				end;

				dw:=POccEl(p+i)^.id and $C0000000;
				if dw=$40000000 then begin			//	is ID
					lastID:=POccEl(p+i)^.id and $3FFFFFFF; // id merken (falls gleiche ID)
					lastI:=i+4;							// Zeiger auf letztes datEl (Gewicht) merken (für ev. last flag unten)
					i+=occLen							// um occLen (8,10 oder 12 Bytes) weitergehen				
				end else if dw=$80000000 then begin	// $C0000000 (id+full flag) kommt hier nicht vor (not isFull...)
					len:=POccEl(p+i)^.clen and $3FFFFFFF; // len flag gefunden
					BREAK
				end else begin	
					lastI:=i;							// wie oben letztes DatEl für ev. last flag merken
					i+=occLen-4;						// is data=> um 4,6 oder 8 Bytes weiter bis wenigstens Bit=$40000000 gesetzt ist								
				end;
			end;
			if (len=0) or (len>maxCluster) or (i>=len*occLen) then begin result:=-306; EXIT; end;	// Fehler: Keine sinnvolle Längenangabe gefunden
			SetContReadLen(len);						// Leselänge per Statistik optimieren
			j:=occLen;									// 8-12 Byte Platzbedarf
			if id=lastID then j-=4;					// Wiederholung der ID (4 Byte) kann bei sortierter Einfügung Gleicher entfallen
			if i+j > len*occLen then begin
				POccEl(p+lastI)^.gewicht:=POccEl(p+lastI)^.gewicht or $80; // last flag in letztem Gewicht setzen
				POccEl(p)^.id:=POccEl(p)^.id or $80000000; // full flag in erster ID setzen (=> $C0000000)
				POccEl(p+i)^.clen:=0;				// Längen-DWord löschen
				i+=4;
				isFull:=true;							// verbleibender Platz reicht nicht aus - Platz bleibt leer => neuen Cluster anlegen (s.u.)
				dirty:=true;							// Record muss komplett abgespeichert werden
			end else begin
				if id<>lastID then begin
					POccEl(p+i)^:=idEl; i+=4;		// Wort aus anderem Text: ID muss gesetzt werden				
				end;
				lastI:=i;								// index für mögliches last flag merken
				POccEl(p+i)^:=datEl; i+=4;
				if occLen>8 then begin
					POccEl(p+i)^:=moreDatEl; 
					i+=occLen-8;
				end;

				if i+occLen-4<=len*occLen then begin // es verbleibt noch Platz für mindestens einen weiteren Eintrag
					POccEl(p+i)^.clen:=len or $80000000; // len flag im ersten noch unbenutzten Eintrag vermerken
					i+=4;									// um Länge der Länge (4) zum Schreiben erhöhen
				end else begin							// sonst im ersten Eintrag das Flag "voll" setzen
					POccEl(p+lastI)^.gewicht:=POccEl(p+lastI)^.gewicht or $80; 	// last flag setzen
					POccEl(p)^.id:=POccEl(p)^.id or $80000000;	// full Flag in der ersten ID setzen. Zum Platz-Optimieren siehe unten ¹)
				end;
				occStream.Seek(aktKey+cluDaLen[aktKey=key],soFromBeginning); // FÄLLE 2+3: freien Platz im Erst- bzw. ContCluster gefunden
				occStream.Write(p^,i);				// Occs abspeichern
				EXIT										// und fertig
			end;
		end;

		if isFull then begin
			// Zum Platz-Optimieren siehe unten ¹)
			if (recycling) and (nextCluster<>0) then begin	// auch in nicht-letzten Clustern soll Platz aus gelöschten Einträgen recycled werden
				if dirty then begin					// ggf. zunächst die oben geänderten Daten (full+last flags) speichern
					occStream.Seek(aktKey+cluDaLen[aktKey=key],soFromBeginning);
					occStream.Write(p^,i);			// Records (hier ohne Header) soweit beschrieben abspeichern
					dirty:=false;
				end;
				
				while (isFull) and (nextCluster<>0) do begin
					tmpKey:=nextCluster;
					occStream.Seek(tmpKey,soFromBeginning);
					occStream.Read(tmpOcc^,4+occLen); // nur Header und ersten Record lesen
					if (tmpOcc^.occs[0].id and $C0000000<>$C0000000) then
						isFull:=false
					else
						nextCluster:=tmpOcc^.next
				end;
				if isFull then begin
					occ^:=tmpOcc^;						// für next-Verzeigerung unten den letzten Record aus der Kette benutzen!
					aktKey:=tmpKey;
				end else begin
					firstOcc^.last:=nextCluster;	// last-Zeiger auf den oben gefundenen, teil-freien Cluster setzen
					occStream.Seek(key,soFromBeginning);
					occStream.Write(firstOcc^,4); // nur den last-Zeiger speichern und dann Rekursion aufrufen
					result:=InsertRecord(key,size,elID,elPos,elDate,elWeight,elInfo); // hier läuft es dann auf Fall 3 hinaus
					EXIT									// Ende nach Rekursion
				end;
			end;
			
			newKey:=NewCluster(size,false);
			if aktKey=key then 						// aktueller ist Erstcluster
				firstOcc^.next:=newKey				// also Vorwärtszeiger dort setzen
			else begin									// aktueller (occ @ aktKey) ist Fortsetzungscluster
				occ^.next:=newKey;					// Vorwärtszeiger im Vorgänger-Cluster setzen
				occStream.Seek(aktKey,soFromBeginning);
				if dirty then begin
					occStream.Write(occ^,4+i);		// Cluster komplett abspeichern (ggf. oben flags verändert) 
					dirty:=false;
				end else
					occStream.Write(occ^,4);		// nur dessen "next"-Feld abspeichern 
			end;

			firstOcc^.last:=newKey;					// neuen last-Zeiger im Erstcluster setzen
			occStream.Seek(key,soFromBeginning);
			if dirty then begin
				occStream.Write(firstOcc^,8+i); 	// Cluster komplett abspeichern (full flag s.o.)
				dirty:=false
			end else
				occStream.Write(firstOcc^,8);		// nur dessen "last" und "next"-Felder abspeichern

			if size=1 then begin
				idEl.id:=idEl.id or $80000000; 	// full flag setzen (=> $C0000000)
				datEl.gewicht:=datEl.gewicht or $80; // last flag setzen
			end;
			fillWord(occ^,(4+occLen*size) shr 1,0);
			with occ^ do begin
				occs[0]:=idEL;
				occs[1]:=datEl;
				if occLen>8 then 	occs[2]:=moreDatEl;
				if size>1 then begin
					p:=@occs; 
					PoccEl(p+occLen)^.clen:=size or $80000000;// len flag setzen
				end;
			end;				
			occStream.Seek(newKey,soFromBeginning);
			occStream.Write(occ^,4+occLen*size);// neuen Cluster wegen Dateilänge unbedingt komplett abspeichern
		end;												// Fall 4 ist fertig
	except
		on E:Exception do begin writeln(' EX=',E.message,' in occtable2.InsertRecord'); result:=-304; end;
	end;
end;


function TClusterMasterD.GetItemList(key:cardinal; callback:TTraverse; countOnly:boolean):longint;
var
	p								:	PByte;
	i,id,r,aktKey,firstKey	:	cardinal;
	l								:	longint;
	n								:	integer;
	last,isFull					:	boolean;
	
begin
	n:=0; firstKey:=key;
	if (callback=NIL) and not (countOnly) then begin
		if resList=NIL then resList:=TDWList.Create(maxlongint) else resList.Clear;
	end;
	while key>0 do 
	try
		aktKey:=key;
		occStream.Seek(key,soFromBeginning);
		if key=firstKey then with firstocc^ do begin
			l:=occStream.Read(firstOcc^,8+def1stReadLen);
			if l=0 then begin
				result:=-315; EXIT
			end;
			key:=next;
			p:=@occs;
		end else with occ^ do begin
			l:=occStream.Read(occ^,4+def1stReadLen);
			if l=0 then begin
				result:=-315; EXIT
			end;
			key:=next;
			p:=@occs;
		end;
		if (key=aktKey) then begin
			result:=-316; EXIT
		end;
		
		i:=0; last:=false; r:=def1stReadLen;
		isFull:=POccel(p)^.id and $C0000000=$C0000000;
		while not last do begin
			if (POccel(p+i)^.id and $40000000<>0) then begin	//	nicht bei len flag ($80000000)
				id:=0; 
				repeat
//write(firstKey:10,id:10);
					GetItem(p,last,i,r,id,callback);	inc(n); 
//writeln(' => ',id:10,i:10,last:10,aktKey:10,key:10);					
				until (last) or (POccel(p+i)^.id and escMask[isFull]<>0) or (i>fullClusterLen);
				if i>fullClusterLen then begin
					result:=-314; EXIT;				// normales Abbruchkriterium nicht gefunden: Liste inkonsistent!
				end;
			end else 
				BREAK										// len flag ist - wie last flag - ein Abbruchkriterium
		end;
	except
		on EStreamError do result:=-304;
	end;

	result:=n;
end;


function TClusterMasterD.InvalidateRecord(key,fid:cardinal):longint;
var
	p																	:	PByte;
	firstKey,aktKey,id,i,m,startI,lastI,lastGI,len,r,z	:	cardinal;
	l																	:	longint;
	n																	:	integer;
	last,rpt,isFull,wasFull										:	boolean;
// tron:boolean;
begin
//	trOn:=false; //key=15942;
	
	n:=0; firstKey:=key; result:=0;
	while key>0 do
	try
		aktKey:=key;
		occStream.Seek(key,soFromBeginning);
		if key=firstKey then with firstocc^ do begin
			l:=occStream.Read(firstOcc^,8+def1stReadLen);
			if l=0 then begin result:=-317; EXIT; end;
			key:=next;
			p:=@occs;
		end else with occ^ do begin
			l:=occStream.Read(occ^,4+def1stReadLen);
			if l=0 then begin	result:=-318; EXIT; end;
			key:=next;
			p:=@occs;
		end;
		if (key=aktKey) then begin
			result:=-319; EXIT
		end;

		z:=$FFFFFFFF; r:=def1stReadLen; 
		wasFull:=POccel(p)^.id and $C0000000=$C0000000; 
		repeat
			i:=0; startI:=$FFFFFFFF; lastI:=0; lastGI:=0; len:=0; last:=false; rpt:=false; 
			isFull:=POccel(p)^.id and $C0000000=$C0000000; 
			repeat			
				if (POccel(p+i)^.id and $40000000<>0) then begin	//	nicht bei len flag ($80000000)
					id:=0;
//if tron then writeln('x:',i:10,id:10);
					repeat
//if tron then writeln('0:',i:10,id:10);
						if id=0 then begin 
							if i+occLen>r then begin
								GetData(p,r); if i+occLen>r then begin result:=-310; EXIT end // nicht genug Daten vorhanden
							end;
							id:=POccEl(p+i)^.id and $3FFFFFFF;
							if id=fid then begin
								if startI<>$FFFFFFFF then begin // ID-Wiederholung, dieser Fall kann nur nach
									rpt:=true; 
									if lastI=0 then lastI:=i;	  // nachträglichem Verschieben im Cluster eintreten
//if tron then writeln('rpt: ',aktKey:10,startI:10,lastI:10,i:10,id:10,n:10);									
								end else begin	
									startI:=i; inc(n);
//if tron then writeln('1st: ',aktKey:10,startI:10,lastI:10,i:10,id:10,n:10);
								end;
					 		end else if (startI<>$FFFFFFFF) and (lastI=0) then 
								lastI:=i; 
							i+=4;
//if tron then writeln('1:',i:10,id:10);
						end else begin
							if i+occLen-4>r then begin
								GetData(p,r); if i+occLen-4>r then begin result:=-310; EXIT end 
							end;
							if (startI<>$FFFFFFFF) and (lastI=0) then begin
//if tron then writeln('wdh: ',aktKey:10,startI:10,lastI:10,i:10,'       n=',n:10);
								inc(n);
							end;
						end;	

//if tron then writeln('2:',i:10,id:10);
						if POccel(p+i)^.gewicht and $80<>0 then begin
							if not isFull then begin result:=-311; EXIT end;	// Gewicht darf nicht in teil-leeren Cluster vorkommen
							lastGI:=i; last:=true;
							len:=(i+occLen) div occLen;
//if tron then writeln('3:',i:10,id:10);
						end;
//if tron then writeln('4:',i:10,id:10);
						i+=occLen-4;
//if tron then writeln('5:',i:10,id:10);
						if i+4>r then GetData(p,r);
						last:=last or (i+4>r);
//if tron then writeln('6:',i:10,id:10,last:10,escMask[isFull]:10,escMask[isFull]<>0);
					until (last) or (POccel(p+i)^.id and escMask[isFull]<>0) or (i>fullClusterLen);
					if i>fullClusterLen then begin
						result:=-314; EXIT;			// kein Abbruchkriterium gefunden: Liste inkonsistent!
					end;
				end else begin
					if isFull then begin	result:=-313; EXIT; end;	// Länge darf nicht in vollem Cluster vorkommen
					len:=POccel(p+i)^.clen and $3FFFFFFF;
					last:=true							// len flag ist - wie last flag - ein Abbruchkriterium
				end;
			until last;

			if startI<>$FFFFFFFF then begin
				if (len=0) or (len>maxCluster) then begin
					result:=-312; EXIT 				// keine (gültige) Länge gefunden bzw. errechnet
				end;
				if lastI=0 then lastI:=i; m:=0;
				if lastI>=i then						// zu löschende ID liegt am Ende des Clusters (rpt niemals true!)
					z:=startI
				else begin								// last flag löschen und Daten verschieben
					if lastGI<>0 then POccel(p+lastGI)^.gewicht:=POccel(p+lastGI)^.gewicht and $7f; // last flag löschen
					m:=i-lastI;
					try
						move(POccel(p+lastI)^,POccel(p+startI)^,m);
					except
						result:=-321; EXIT;
					end;
					z:=startI+m;
				end;
//if tron then writeln('KFW: ',aktKey:10,startI:10,lastI:10,i:10,m:10,n:10);				
				if z>0 then POccel(p)^.id:=POccel(p)^.id and $7FFFFFFF; // full flag löschen
				POccel(p+z)^.clen:=len or $80000000;	// neue Länge (als Endemarke) eintragen
			end;
		until not rpt;

		if z<>$FFFFFFFF then begin
			occStream.Seek(aktKey+cluDaLen[aktKey=firstKey],soFromBeginning);
			occStream.Write(p^,z+4);
			if (recycling) and (wasFull) and (firstOcc^.last>aktKey) then begin // last-Zeiger des ersten Clusters auf akt. Cluster (zum späteren "Nachfüllen") setzen
				if aktKey=firstKey then	firstOcc^.last:=0 else firstOcc^.last:=aktKey;
				occStream.Seek(firstKey,soFromBeginning);
				occStream.Write(firstOcc^,4);
			end;
		end;
		
	except
		on E:Exception do begin writeln(' EX=',E.message,' in occtable.InvalidateEntry'); result:=-321; end;
		on EStreamError do result:=-309;
	end;
	result:=n;
end;


// Datenhaltung im Arbeitsspeicher (nach Programmschluss oder "Commit" auf Disk zurückgeschrieben)

constructor TClusterMasterM.Create(const name:string; elSize,initSize,growSize:longint; readOnly,enableRecycling:boolean; var res:integer);
begin
	inherited Create(name,elSize,readOnly,enableRecycling,res);
	if res<>0 then EXIT;
	occStream.Free;						// TFileStream freigeben
	occStream:=TLargeMemoryStream.Create(0,growSize);	// als TLargeMemoryStream neu anlegen
	with occStream as TLargeMemoryStream do LoadFromFile(myFileName); 
	if (initSize>0) and (not ro) then with occStream as TLargeMemoryStream do SetSize(initSize); // erst hier sinnvoll, weil LoadFromFile die Capacity einstellt
end;


destructor TClusterMasterM.Destroy;
begin
	Commit;
	inherited Destroy;
end;


procedure TClusterMasterM.Clear;
begin
	with occStream as TLargeMemoryStream do Clear;
	occStream.WriteDWord(occLen);
end;


procedure TClusterMasterM.Commit;
var
	store	:	TFileStream;
	n		:	cardinal;
begin
	if ro or (occStream=NIL) then EXIT;
	occStream.Seek(0,soFromBeginning);
	store:=TFileStream.Create(myFileName,fmCreate);
	if occStream.Size<nextKey then n:=occStream.Size else n:=nextKey;
	store.CopyFrom(occStream,n);
	store.Free;
end;


end.

//	¹) Nach dem Einfügen ist das Platz optimieren wg. nachträglicher Löschungen und damit verbundener 
// Verschiebungen nicht mehr erlaubt! Der Code war:
//	if (nextKey-(aktKey+cluDaLen[aktKey=key]+i) < occLen+4) then nextKey:=aktKey+cluDaLen[aktKey=key]+i; 
