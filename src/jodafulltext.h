#ifndef JODAFULLTEXT_H
#define JODAFULLTEXT_H
/*
 * joda.h
 * an C header for libjodafulltext by Oliver Graf, Kevag Telekom GmbH
 * 
 * joda         - Copyright (c) 2000-2002 by Jochen Magnus
 * jodafulltext - Copyright (c) 2002 by RZ-Online GmbH & Kevag Telekom GmbH
 * 
 */

/*
 * Sort Order.
 */
typedef enum {
  joda_sortByWeight = 0x0001,
  joda_sortByAge    = 0x0002
} jodaSortOrder;

typedef int jodaHandle;

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
 * int jodaSortIssues( handle, s)
*/
void jodaSortIssues( jodaHandle handle, char *issueParams);

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
int jodaGetOneHit ( int handle, int hit, int maxlen, char *buffer);

/*
 * int jodaGetAllHits ( handle, hits, maxlen, buffer)
 */
int jodaGetAllHits ( int handle, int hits, int maxlen, char *buffer);

/*
 * int jodaStore ( handle, words, fileName, date, info, id )
 */
int jodaStore ( int handle, char *words, char *fileName, char *date,
				int info, int *id);

/*
 * int jodaInvalidateEntry ( handle, words, id )
 */
int jodaInvalidateEntry ( int handle, char *words, int id);

/*
 * end of jodafulltext.h
 */
#endif /* JODAFULLTEXT_H */
