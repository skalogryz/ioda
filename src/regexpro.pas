Unit RegExprO;

(* Class package for Unit regexpression *)

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
	RegExpression;

type
	TRegEx	=	class
						constructor Create(pattern:string);
						destructor	Destroy; OVERRIDE;
						function 	MatchPos(s:string; var index,len:integer):boolean;
						function 	Match(const s:string):boolean;
						
						PROTECTED
						rex 		:  TRegExprEngine;
					end;


IMPLEMENTATION

constructor TRegEx.Create(pattern:string);
begin
	inherited Create;
	pattern:=pattern+#0;
	rex:=GenerateRegExprEngine(@pattern[1],[]);
end;


destructor TRegEx.Destroy; 
begin
	DestroyregExprEngine(rex);
end;


function TRegEx.Match(const s:string):boolean;
var
	l,i	:	integer;
begin
	l:=0; i:=0;
	result:=MatchPos(s,l,i);
end;


function TRegEx.MatchPos(s:string; var index,len:integer):boolean;
begin	   
	s	   := s+#0;
	result := RegExprPos(rex,@s[1],index,len);
	index  := index+1;
end;	   

end.
