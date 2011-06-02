#include "qcall.h"

#ifndef QC_PURE
#include <stdlib.h>
#include <stdio.h>
#endif
#define cc HH::

#pragma qc class HH
#ifdef QC_PURE
int x;
int y;
#endif

int cc sum(){
return x + y;
}
#pragma qc endc

int main(){
	HH a;
a.x = 3;
a.y = 8;
int s;
s = a.sum();
printf("the sum = %d\n", s);
}
