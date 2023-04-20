UNIT JStreams;

// Ableitung von TMemoryStream mit der Option, Start- und Erweiterungsgrößen
// zu bestimmen. Wichtig für große Streams, um zu häufige ReAllocs zu vermeiden

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
	Classes;
	
type
	TLargeMemoryStream = class(TMemoryStream)
		constructor Create(initSize,allocSize:longint);
		destructor  Destroy; OVERRIDE;
		function Realloc(var newCapacity: longint): Pointer;	OVERRIDE;
		
	PROTECTED
		iSize,
		aSize	:	longint;
	end;
	
	
IMPLEMENTATION

constructor TLargeMemoryStream.Create(initSize,allocSize:longint);
begin
	inherited Create;
	iSize:=initSize;
	aSize:=allocSize;
	if aSize=0 then aSize:=8192;
   if initSize>0 then SetSize(initSize);
// writeln('CAP=',size);
end;


destructor TLargeMemoryStream.Destroy;
begin
	inherited Destroy
end;


function TLargeMemoryStream.ReAlloc(var newCapacity: Longint): Pointer;
begin
	if newCapacity>0 then 			// round off to block size.
   	newCapacity := (newCapacity + (aSize-1)) and not (aSize-1);
 	result:=inherited ReAlloc(newCapacity);
end;


end.
