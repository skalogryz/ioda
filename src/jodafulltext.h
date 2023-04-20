#ifndef JODAFULLTEXT_H
#define JODAFULLTEXT_H
/*
 * joda.h
 * an C header for libjodafulltext by Oliver Graf, Kevag Telekom GmbH
 */
 
/*  Copyright (C) 1994-2004  ograf@rz-online.net & jo@magnus.de
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
*/

/*
 * Sort Order.
 */
typedef enum {
  joda_sortByWeight = 0x0001,
  joda_sortByAge    = 0x0002
} jodaSortOrder;

typedef int jodaHandle;

typedef struct {
  int id;
  int date;
  int weight;
  int info;
  int dup;
  char *fileref;
  char *title;
  char *__sort;
} jodaHit;

/*
 * Database functions
 */

/*
 * handle jodaOpen ( dbname, ro )
 *
 * opens the jodadatabase with the name dbname. if ro is not 0, the
 * database will be opened read-only, if it's zero, the db will be
 * opened in the mode specified in the dbname.config file.
 *
 * returns a database handle (greater 0) or an error (0 or less).
 */
jodaHandle jodaOpen  ( char *dbname, int ro );

/*
 * int jodaClose ( handle )
 */
int jodaClose ( jodaHandle handle );


/*
 * void jodaSortIssues( handle, s) DEPRECATED!
 *
 * s is the sort spec: PATTERN[,PREFERRED]
 * PATTERN is applied to filenames to find the sort key
 * first PREFERRED containing name is moved to top
 * BOTH are REGEXes!
 *
 */
void jodaSortIssues( jodaHandle handle, char *issueParams);
/*
 * NEW Versions:
 *  jodaSortIssuesPP: set as seperate strings
 *  jodaSortIssuesOLP: use offset,length instead of regex for pattern
 *
 */
int jodaSortIssuesPP( jodaHandle handle, char *issuePattern, char *issuePreferred);
int jodaSortIssuesOLP( jodaHandle handle, int offset, int length, char *issuePreferred);

/*
 * int jodaSearch ( handle, query, dstart, dend, fileFilter, maxHits,
 *                  sortOrder, bitFilter, overflow)
 */
int jodaSearch( jodaHandle handle, char *query, char *dstart, char *dend,
				char *fileFilter, int maxHits, int sortOrder, int bitFilter,
				int *overflow);

/*
 * int jodaSearch ( handle, query, dstart, dend, fileFilter, maxHits,
 *                  sortOrder, bitFilter, overflow)
 */
int jodaVLSearch ( jodaHandle handle, char *query, char *dstart, char *dend,
				   char *fileFilter, unsigned char *bitFilter,
				   int bitFilterNum, int maxHits, int sortOrder,
				   int *overflow);

/*
 * int jodaGetOneHit ( handle, hit, maxlen, buffer)
 */
int jodaGetOneHit ( jodaHandle handle, int hit, int maxlen, char *buffer);

/*
 * int jodaGetAllHits ( handle, hits, maxlen, buffer)
 */
int jodaGetAllHits ( jodaHandle handle, int hits, int maxlen, char *buffer);

/*
 * char *jodaGetQuery ( handle )
 *
 * retruns the parsed query of the last search
 */
char *jodaGetQuery( jodaHandle handle );

/*
 * jodaHit **jodaGetHits ( handle )
 */
jodaHit *jodaGetHit ( jodaHandle handle, int hit );

/*
 * jodaHit **jodaGetHits ( handle )
 */
jodaHit **jodaGetHits ( jodaHandle handle, int *hits );

/*
 * int jodaStore ( handle, words, fileName, date, info, &id )
 */
int jodaStore ( jodaHandle handle, char *words, char *fileName, char *date,
				int info, int *id);

/*
 * int jodaInvalidateEntry ( handle, words, id )
 */
int jodaInvalidateEntry ( jodaHandle handle, char *words, int id);

/*
 * int jodaChainDuplicate ( handle, fileName, lastid, &id )
 */
int jodaChainDuplicate ( jodaHandle handle, char *fileName, int lastID, int *id);

/*
 * end of jodafulltext.h
 */
#endif /* JODAFULLTEXT_H */
