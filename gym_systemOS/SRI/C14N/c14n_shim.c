//
//  c14n_shim.c
//  gym_systemOS
//
//  Implementación del C14N inclusivo vía libxml2 (system framework en iOS).
//

#include "c14n_shim.h"

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/c14n.h>
#include <string.h>
#include <stdlib.h>

char *gym_xml_c14n(const char *input, int input_len, int *out_len) {
    if (out_len) { *out_len = 0; }
    if (input == NULL || input_len <= 0) { return NULL; }

    // Parseo sin quitar espacios en blanco (equivale a remove_blank_text=False).
    xmlDocPtr doc = xmlReadMemory(input, input_len, "in.xml", NULL, 0);
    if (doc == NULL) { return NULL; }

    xmlChar *out = NULL;
    // mode 0 = XML_C14N_1_0 (inclusivo); with_comments = 0.
    int len = xmlC14NDocDumpMemory(doc, NULL, 0, NULL, 0, &out);
    xmlFreeDoc(doc);

    if (len < 0 || out == NULL) {
        if (out) { xmlFree(out); }
        return NULL;
    }

    char *result = (char *)malloc((size_t)len);
    if (result == NULL) { xmlFree(out); return NULL; }
    memcpy(result, out, (size_t)len);
    xmlFree(out);

    if (out_len) { *out_len = len; }
    return result;
}

void gym_xml_free(char *p) {
    if (p) { free(p); }
}
