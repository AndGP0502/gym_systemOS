//
//  c14n_shim.h
//  gym_systemOS
//
//  Canonicalización XML 1.0 INCLUSIVA (xml-c14n-20010315) usando libxml2 del
//  sistema iOS. Es exactamente lo que hace lxml (que envuelve libxml2) en el
//  firmador Python, por lo que produce bytes idénticos → firma XAdES-BES válida.
//

#ifndef C14N_SHIM_H
#define C14N_SHIM_H

#include <stddef.h>

/// Canonicaliza `input` (XML UTF-8) con C14N 1.0 inclusivo, sin comentarios.
/// Devuelve un buffer malloc'd (liberar con gym_xml_free) y escribe su longitud
/// en `out_len`. Devuelve NULL si el XML no se pudo parsear.
char *gym_xml_c14n(const char *input, int input_len, int *out_len);

/// Libera el buffer devuelto por gym_xml_c14n.
void gym_xml_free(char *p);

#endif /* C14N_SHIM_H */
