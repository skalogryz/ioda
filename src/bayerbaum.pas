(****************************************************************************)
(*                                                                          *)
(*                               Top-Down-B-Baum                            *)
(*                                                                          *)
(*						    				  jo 11/92                                 *)
(*                           Windows-Portierung 9/94                        *)
(*								    Linux-FP-Portierung 6/01								 *)
(*         Gekürzte Version, die sich auf die in TVolltext genutzte			 *)
(*          Funktionalität beschränkt: Original siehe Unit BayBaum.			 *)
(*	     							  Fehlermeldungen 100-199		       				 *)
(*																									 *)
(****************************************************************************)

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

UNIT Bayerbaum;
{$H-}
INTERFACE
uses
	Classes,SysUtils;

const
	treel		=   255;
	rootpos	=     1;							// 0 steht immer für ungültig!
	bstrlen	=	  19;

type
	Tbaystr	=	string[bstrlen];
	TVal		=	packed record
						s	:	Tbaystr;
						l,
						z,
						dp	:	cardinal;		// sollte nicht 0 sein (siehe Suche)
					end;   								{ Größe: 32 }
	PVal		=  ^TVal;

	TValArr	=	packed array[1..treel] of TVal;

	TResList	=	class(TList)
							PUBLIC
							constructor Create;
							destructor  Destroy; OVERRIDE;
							procedure   Add(const val:TVal);
							procedure 	Insert(i:integer; const val:TVal);
							procedure	Delete(i:integer);
							procedure 	Unsort;
							
							PROTECTED
							procedure   Clear; OVERRIDE;
							function		GetVal(i:integer):TVal;
							procedure	SetVal(i:integer; const val:TVal);
							
							PUBLIC
							property		v[i:integer]:TVal read GetVal write SetVal; DEFAULT;
						end;


	PNode		=	^TNode;
	TNode		=  packed record       				{ Größe: 8K }
						key		:	longint;
						counter	:  word;
						val		:	TValArr;
						r,
						wordCounter,
						nodeCounter,
						allCounter:	cardinal;
						fuell		:	packed array[1..5] of word;
				end;

	TCaller		=	procedure (var akt:TVal) of object;
	
	TBayBaum	=	class
						constructor Create;
						destructor  Destroy; OVERRIDE;
						function 	Insert(s:Tbaystr; dataptr:cardinal):boolean;
						function    SearchWord(s:Tbaystr; var inf,dataptr:cardinal):boolean;
						function    HowMany(s:Tbaystr; strict:boolean):longint;
						function 	Update(s:Tbaystr; newdataptr:cardinal; counter,counterMode:longint):boolean;
						procedure   GetEqual(s:Tbaystr; Caller:TCaller);  // caller=NIL => LastResult
						procedure   GetAlike(s:Tbaystr; Caller:TCaller);
						procedure   GetAll(Caller:TCaller);
						procedure 	Unsort;

						procedure   Commit; VIRTUAL;
						procedure   Clear;  VIRTUAL;
						function    GetElem(var el:TNode;id:cardinal):boolean; VIRTUAL; ABSTRACT;
						function    SetElem(var el:TNode;id:cardinal):boolean; VIRTUAL; ABSTRACT;
						
						PROTECTED
						resList	:	TResList;
						top,
						wordCounter,
						allCounter,
						nodeCounter,
						loadCounter:cardinal;
						bayError	:	integer;
						stopped,
						trOn		:	boolean;

						function    TellError:integer;
						function    TellQuality:integer;
						function    bSearch(s:Tbaystr; alike:boolean; var el:TNode; var i:integer):integer;
						function    Split(var prev,akt:TNode):boolean;
						function    Search(s:Tbaystr;dataptr:cardinal;var el:TNode; var n:integer;strict:boolean):boolean;
						procedure 	AddResult(var val:TVal);
						function		GetResult(i:integer):TVal;
						function 	GetCount:integer;
						
						PUBLIC
						property		Results[i:integer]:TVal read GetResult; DEFAULT;
						//				^^ wenn "caller" der letzten GetXX/TraverseXX-Operation NIL war
						property		Count:integer read GetCount;
						property    Error:integer read tellError;
						property		Stopp:boolean write stopped;
						property		WordCount:cardinal read wordCounter;
						property    AllCount:cardinal read allCounter;
						property	   LoadCount:cardinal read loadCounter;
						property	   NodeCount:cardinal read nodeCounter;
						property		Quality:integer read TellQuality;
						property		TraceOn:boolean read trOn write tron;
				end;


IMPLEMENTATION

// Spezielle TList zum Speichern von BayerBaum-Elementen als Objekte


constructor TResList.Create;
begin
	inherited Create;
end;


destructor TResList.Destroy;
begin
	Clear;
	inherited Destroy
end;


procedure TResList.Clear;
var
	i	:	integer;
	el	:	PVal;
begin
	for i:=0 to count-1 do 
	begin
		el:=items[i];
		if el<>NIL then dispose(el);
	end;
	inherited Clear;
end;


procedure TResList.Add(const val:TVal);
var
	el	:	PVal;
begin
	try	
		new(el); 
	except 
		on EOutOfMemory do EXIT
	end;
	
	el^:=val;
	inherited Add(el);
end;



procedure TResList.Insert(i:integer; const val:TVal);
var
	el	:	PVal;
begin
	try
		new(el);
	except 
		on EOutOfMemory do EXIT
	end;
	
	el^:=val;
	inherited Insert(i,el);
end;


procedure TResList.Delete(i:integer);
var
	el	:	PVal;
begin
	el:=items[i];
	if el<>NIL then dispose(el);
	inherited Delete(i)
end;


procedure TResList.Unsort;
var
	i	:	integer;
begin
	if count<3 then EXIT;
	randomize;
	for i:=0 to 2*count do	// ungefähre Verwirrung, ein paar bleiben natürlich unverändert
		Exchange(random(count-1),random(count-1));
end;


function	TResList.GetVal(i:integer):TVal;
begin
	result:=TVal(items[i]^);
end;


procedure TResList.SetVal(i:integer; const val:TVal);
begin
	TVal(items[i]^):=val;
end;



// Der GANZE Bayerbaum, bloss ohne konkrete Lese- und Schreibmöglichkeiten
constructor TBayBaum.Create;
begin
	inherited Create;
	wordCounter:=0; loadCounter:=0; nodeCounter:=1; allCounter:=0;
	top:=rootpos; bayError:=0; trOn:=false;
	resList:=TResList.Create;
end;


destructor TBayBaum.Destroy;
begin
	resList.Free;
	inherited Destroy;
end;


function TBayBaum.bSearch(s:Tbaystr; alike:boolean; var el:TNode; var i:integer):integer;
var
	ui,oi,j	:	word;
	lastI		:	word;
	t			:	string;

begin
	if (el.counter>treel) or (el.counter<0) then
	begin
		bSearch:=-128; EXIT;
	end;
	oi:=el.counter; ui:=0; i:=0;
	if oi=0 then
	begin
		bSearch:=1; EXIT;
	end;

	repeat
		lastI:=i; j:=ui+oi;
		i:=j div 2; if j mod 2<>0 then inc(i);
		if alike then
			t:=copy(el.val[i].s,1,length(s))
		else
			t:=el.val[i].s;
		if t>s then oi:=i else ui:=i;
	until (t=s) or (lastI=i);

	if s=t then
	begin				{ Zeiger auf 1. gleiches Element zurücksetzen }
		if alike then
			while (i>1) and (t=s) do
			begin
				t:=copy(el.val[i-1].s,1,length(s));
				if t<>s then break;
				dec(i);
			end
		else
			while (i>1) and (t=s) do
			begin
				t:=el.val[i-1].s;
				if t<>s then break;
				dec(i);
			end;
		bSearch:=0;
	end else if s>t then
		bSearch:=1
	else
		bSearch:=-1;
end;		{ bSearch }



function TBayBaum.Split(var prev,akt:TNode):boolean;
var
	neu	  	:	PNode;
	c1,c2,i	:	integer;

begin
	result:=false;
	try 
		new(neu); 
	except 
		on EOutOfMemory do 
		begin 
			bayError:=101; EXIT; 
		end; 
	end;

	c1:=akt.counter div 2;
	if akt.counter mod 2=0 then c2:=c1-1 else c2:=c1;
	fillDWord(neu^,sizeof(TNode) shr 2,0); neu^.key:=top;
	inc(top,sizeof(TNode));	inc(nodeCounter);

	akt.counter:=c1;
	neu^.counter:=c2;
	neu^.r:=akt.r; akt.r:=0;

	for i:=1 to neu^.counter do    		{ neu ist der rechte (größere) Teilknoten 	}
	begin                              	{ rechte Hälfte von AKT -> NEU umladen 		}
		neu^.val[i]:=akt.val[i+c1+1];
		fillDWord(akt.val[i+c1+1],sizeOf(TVal) shr 2,0);
	end;

	if akt.key=rootpos then					{ =PREV=AKT=Sonderfall: root ist voll	 	}
	begin
		akt.key:=top;							{ neue Adresse für alten root }
		inc(top,sizeof(TNode)); inc(nodeCounter);

		fillDWord(prev,sizeof(TNode) shr 2,0);
		with prev do
		begin
			key:=rootpos;						{ PREV wird neuer root }
			r:=neu^.key; 
			counter:=1;
		end;
		i:=1;                            { für Behandlung unten }
	end else
	begin                               { Normalfall: Mitte von AKT nach oben reichen}
		case bSearch(akt.val[c1+1].s,false,prev,i) of
		  -1,0 :	begin                              { links oder drin einfügen 	}
						prev.val[i].l:=neu^.key;
						move(prev.val[i],prev.val[i+1],sizeof(TVal)*(prev.counter-i+1));
					end;
			1 :  	begin                    { rechts anfügen }
						prev.r:=neu^.key;
						inc(i);
					end;
		  -128 : begin
						dispose(neu); EXIT;
					end;
		end;
		inc(prev.counter);
	end;

	prev.val[i]:=akt.val[c1+1];
	prev.val[i].l:=akt.key;
	akt.r:=akt.val[c1+1].l;
	fillDWord(akt.val[c1+1],sizeOf(TVal) shr 2,0);
	result:=setElem(prev,prev.key) and setElem(akt,akt.key) and setElem(neu^,neu^.key);
	dispose(neu);
end;


function TBayBaum.Insert(s:Tbaystr; dataptr:cardinal):boolean;
{
  INSERT sucht ein passendes Blatt des Baumes und sortiert dort das neue
  Element ein. Werden während der Suche volle Knoten bemerkt, ruft sich
  INSERT nach der Aufspalteprozedur SPLIT rekursiv wieder auf (TOP-DOWN-BBAUM).
}

var
	root,akt,prev	:	PNode;
	i,zwi				:	integer;
	found,ok			:	boolean;

begin
	Insert:=false; 
	root:=NIL; akt:=NIL; prev:=NIL;
	if dataptr<=0 then 
	begin
		bayError:=102; EXIT;                     { =0 als Fehler: jo 16.2.95 }
	end;
	try 
		new(root);
		fillDWord(root^,sizeof(TNode) shr 2,0);
		root^.key:=rootpos;
		new(akt); 
		new(prev); 
	except 
		on EOutOfMemory do 
		begin 
			if akt<>NIL then dispose(akt);
			if root<>NIL then dispose(root);
			bayError:=101; EXIT; 
		end; 
	end;

	GetElem(root^,rootpos);
	prev^:=root^; akt^:=root^; loadCounter:=0; i:=0;
	s:=AnsiUpperCase(s);
	found:=false; ok:=true;
	repeat
		if akt^.counter=treel then
		begin
			ok:=Split(prev^,akt^);
			if not ok then bayError:=104;
			dispose(prev); dispose(akt); dispose(root); 
			result:=ok and Insert(s,dataptr);		{ Rekursion nach SPLIT }
			EXIT;
		end;
		prev^:=akt^;

		zwi:=bSearch(s,false,akt^,i);
		if zwi=-128 then
		begin
			dispose(prev); dispose(akt); dispose(root); bayError:=107; EXIT;
		end;

		if zwi=0 then
		begin
			inc(akt^.val[i].z);
			if setElem(akt^,akt^.key) then
			begin
				inc(allCounter); result:=true;
			end else
			begin
				bayError:=108; result:=false; 
			end;
			dispose(prev); dispose(akt); dispose(root); EXIT;
		end;
		
		if zwi<0 then
		begin
			if akt^.val[i].l<>0 then
			begin
				ok:=getElem(akt^,akt^.val[i].l); inc(loadCounter);
				if not ok then bayError:=105;
			end else
			begin
				found:=true;            { Elemente im Blatt verschieben }
				move(akt^.val[i],akt^.val[i+1],sizeof(TVal)*(akt^.counter-i+1));
			end;
		end else
		begin
			if (i>0) and (akt^.r<>0) then
			begin
				ok:=getElem(akt^,akt^.r); inc(loadCounter);
			end else							{ auch: leeres Blatt! }
			begin
				found:=true; inc(i);  	{ neues Element wird letztes (größtes) im Blatt }
			end;
	end;
	until found or not ok;

	fillDWord(akt^.val[i],sizeOf(TVal) shr 2,0);
	akt^.val[i].s:=s; akt^.val[i].dp:=dataptr; akt^.val[i].z:=1;

	if ok then 
	begin
		inc(akt^.counter);
		if SetElem(akt^,akt^.key) then
		begin
			inc(wordCounter); inc(allCounter);
		end else
		begin
			ok:=false; bayError:=103;
		end;
	end;

	dispose(prev); dispose(akt); dispose(root);
	result:=ok;
end;


function TBayBaum.Search(s:Tbaystr;dataptr:cardinal;var el:TNode;var n:integer;strict:boolean):boolean;
// Suche AB(!) el nach EINEM Element MIT BESTIMMTEM DATAPTR, wenn DATAPTR<>0 
var
	found	:	boolean;


	procedure Visit(id:longint; r:integer);
	var
		akt	:	PNode;
		i		:	integer;

	begin
		if id=0 then EXIT;
		if r>1024 then begin writeln('FATAL: BAYERBAUM FALSCH VERKETTET!'); Destroy; HALT(99); end;

		try 
			new(akt); 
		except 
			on EOutOfMemory do 
			begin
				bayError:=101; EXIT
			end;
		end;

		if GetElem(akt^,id) and (akt^.key<>0) and (akt^.counter>0) then
		begin
			inc(loadCounter);
			case bSearch(s,not strict,akt^,i) of
			 0 :	if ((dataptr=0) or (akt^.val[i].dp=dataptr)) then
					begin
						el:=akt^; n:=i; found:=true;
					end;
			 -1: 	Visit(akt^.val[i].l,r+1);
			  1:  Visit(akt^.r,r+1);
			end;
		end;
		dispose(akt);
	end;

begin
	s:=AnsiUpperCase(s);
	found:=false;
	Visit(el.key,0);
	Search:=found;
end;


function TBayBaum.SearchWord(s:Tbaystr; var inf,dataptr:cardinal):boolean;
var
	el			:	PNode;
	i			:	integer;
	strict	:	boolean;
begin
	result:=false;
	try 
		new(el); 
	except 
		on EOutOfMemory do 
		begin
			bayError:=101; EXIT
		end;
	end;
	if s[length(s)]='*' then
	begin
		dec(s[0]); strict:=false;
	end else
		strict:=true;

	el^.key:=rootpos;
	if Search(s,0,el^,i,strict) then
	begin
		SearchWord:=true;
		inf:=el^.val[i].z;
		dataptr:=el^.val[i].dp;
	end else
	begin
		inf:=0; dataptr:=0;
	end;

   dispose(el);
end;


function TBayBaum.HowMany(s:Tbaystr; strict:boolean):longint;
var
	found	:	longint;


	procedure Visit(id:longint);
	var
		akt	:	PNode;
		t	:	Tbaystr;
		i,n	:	integer;
		ok	:	byte;

	begin
		if id=0 then EXIT;

		try 
			new(akt); 
		except 
			on EOutOfMemory do 
			begin
				bayError:=101; EXIT
			end;
		end;
		
		if getElem(akt^,id) and (akt^.key<>0) and (akt^.counter>0) then
		begin
			inc(loadCounter);
			case bsearch(s,not strict,akt^,i) of
			  0 : begin
					ok:=0;
					repeat
						n:=i;
						if not strict then
						begin
							t:=copy(akt^.val[i].s,1,length(s));
							if s<>t then inc(ok);
						end;
						inc(found,akt^.val[i].z);
						inc(i);
					until strict or (i>akt^.counter) or (ok=2);

					if not strict then
					begin
						Visit(akt^.val[n].l);
						Visit(akt^.r);
					end;
				 end;
			 -1 : Visit(akt^.val[i].l);
			  1 : Visit(akt^.r);
		    -128 : begin
					dispose(akt); EXIT;
				 end;
			end;
		end;
		dispose(akt);
	end;

begin
	s:=AnsiUpperCase(s);
	found:=0;
	Visit(rootpos);
	howMany:=found;
end;


procedure TBayBaum.AddResult(var val:TVal);
begin
	resList.Add(val);
end;


function TBayBaum.GetResult(i:integer):TVal;
begin
	try	
		result:=resList[i];
	except
		on EListError do 
		begin
			bayError:=-106; result.s:='';
		end;
	end;
end;


function TBayBaum.GetCount:integer;
begin
	result:=resList.Count;
end;


procedure TBayBaum.Unsort;
begin
	resList.Unsort
end;


procedure TBayBaum.GetEqual(s:Tbaystr; Caller:TCaller);


	procedure Visit(id:longint);				{ Inorder-Traversierung }
	var
		akt	:	PNode;
		i		:	integer;

	begin
		if (id=0) or stopped then EXIT;

		try 
			new(akt); 
		except 
			on EOutOfMemory do 
			begin
				bayError:=101; EXIT
			end;
		end;

		if getElem(akt^,id) and (akt^.key<>0) and (akt^.counter>0) then
		begin
			 inc(loadCounter);
			 case bSearch(s,false,akt^,i) of
			  0 	:	Caller(akt^.val[i]);
			 -1 	: 	Visit(akt^.val[i].l);
			  1	: 	Visit(akt^.r);
			end;
		end;
		dispose(akt);
	end;

begin
	s:=AnsiUpperCase(s);
	loadCounter:=0; stopped:=false; resList.Clear;
	if caller=NIL then caller:=@AddResult;
	Visit(rootpos);
end;


procedure TBayBaum.GetAlike(s:Tbaystr; Caller:TCaller);


	procedure Visit(id:longint);				{ Inorder-Traversierung }
	var
		akt	:	PNode;
		t		:	Tbaystr;
		i  	:	integer;
		ok 	:	byte;

	begin
		if (id=0) or stopped then EXIT;

		try 
			new(akt); 
		except 
			on EOutOfMemory do 
			begin
				bayError:=101; EXIT
			end;
		end;

		if getElem(akt^,id) and (akt^.key<>0) and (akt^.counter>0) then
		begin
			inc(loadCounter);
			case bsearch(s,true,akt^,i) of
			 0 :	begin
					ok:=0;
					repeat
						Visit(akt^.val[i].l);
						if ok=0 then Caller(akt^.val[i]);
						inc(i); 
						if i<=akt^.counter then	t:=copy(akt^.val[i].s,1,length(s)); 
						if s<>t then inc(ok);
					until (i>akt^.counter) or (ok=2);
					Visit(akt^.r);			{ wegen gleichen Einträgen infolge Split }
				end;
			 -1: Visit(akt^.val[i].l);
			  1: Visit(akt^.r);
		    -128: begin
					dispose(akt); EXIT;
				end;
			end;
		end;
		dispose(akt);
	end;

begin
	s:=AnsiUpperCase(s);
	loadCounter:=0; stopped:=false; resList.Clear;
	if caller=NIL then caller:=@AddResult;
	Visit(rootpos);
end;


procedure TBayBaum.GetAll(Caller:TCaller);


	procedure Visit(id:longint);				{ Inorder-Traversierung }
	var
		akt	:	PNode;
		i		:	integer;

	begin
		if (id=0) or stopped then EXIT;
		try 
			new(akt); 
		except 
			on EOutOfMemory do 
			begin
				bayError:=101; EXIT
			end;
		end;

		if GetElem(akt^,id) and (akt^.key<>0) and (akt^.counter>0) then
		begin
			for i:=1 to akt^.counter do
			begin
				Visit(akt^.val[i].l);
				Caller(akt^.val[i]);
			end;
			Visit(akt^.r);
		end;
		dispose(akt);
	end;

begin
	stopped:=false; resList.Clear;
	if caller=NIL then caller:=@AddResult;
	Visit(rootpos);
end;


function TBayBaum.TellError:integer;
begin
	result:=bayError; 
	bayError:=0;
end;


function TBayBaum.TellQuality:integer;


	function LG(n:longint):shortint;	{ errechnet ganzzahligen Anteil von LOG100n }
	var
		i	:	shortint;
	begin
		i:=0;
		while n>0 do
		begin
			n:=n div 100; inc(i);
		end;
		LG:=i;
	end;


begin
	if wordCounter=0 then
		TellQuality:=0
	else
		TellQuality:=round((allCounter/wordCounter)*LG(wordCounter));
end;


function TBayBaum.Update(s:Tbaystr; newdataptr:cardinal; counter,counterMode:longint):boolean;
var
	akt	:	PNode;
	i		:	integer;
	
begin
	Update:=false;
//	if wordCounter=0 then EXIT;
	
	try 
		new(akt); 
	except 
		on EOutOfMemory do 
		begin
			bayError:=101; EXIT
		end;
	end; 
	
	loadCounter:=0; akt^.key:=rootpos;
	if Search(s,0,akt^,i,true) then
	begin
		akt^.val[i].dp:=newdataptr;
		if counter<>0 then
		begin
			if counterMode=0 then	// Counter ist absolute Anzahl
			begin
				allCounter+=cardinal(counter)-akt^.val[i].z;
				akt^.val[i].z:=counter;
			end else if ((counter>0) or (akt^.val[i].z>=cardinal(abs(counter)))) then begin
				inc(akt^.val[i].z,counter);
				inc(allCounter,counter);
			end;		
		end;
		Update:=SetElem(akt^,akt^.key);
	end;
	dispose(akt);
end;


procedure TBayBaum.Commit;
begin end;


procedure TBayBaum.Clear;
begin end;

end.
