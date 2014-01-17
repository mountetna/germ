#include "ruby.h"
#include "ruby/io.h"
#include "stdio.h"
#include <string.h>

VALUE FastaAux = Qnil;

void Init_fasta_aux();
VALUE method_get_seq_starts(VALUE self);
VALUE method_get_nmer_freq(VALUE self, VALUE seq, VALUE n);
VALUE method_get_seq_chunk(VALUE self, VALUE pos1, VALUE pos2);
FILE *get_io_ptr(VALUE self);

FILE *get_io_ptr(VALUE self) {
	VALUE io;
	io = rb_iv_get(self,"@io");
	return rb_io_stdio_file(RFILE(io)->fptr);
}

void Init_fasta_aux() {
	FastaAux = rb_define_module("FastaAux");
	rb_define_method(FastaAux, "get_seq_starts", method_get_seq_starts, 0);
	rb_define_method(FastaAux, "get_seq_chunk", method_get_seq_chunk, 2);
	rb_define_method(FastaAux, "get_nmer_freq", method_get_nmer_freq, 2);
}

#define BUF_SIZE 1200

VALUE method_get_seq_chunk(VALUE self, VALUE pos1, VALUE pos2) {
	// extract the sequence between pos1 and pos2
	FILE * fd;
	char *buf;
	unsigned int p1, p2;
	VALUE s;
	p1 = NUM2UINT(pos1);
	p2 = NUM2UINT(pos2);
	fd = get_io_ptr(self);
	buf = ALLOC_N(char,p2-p1+1);
	fseek(fd,p1,SEEK_SET);
	fread(buf,1,p2-p1+1,fd);
	s = rb_str_new(buf,p2-p1+1);
	xfree(buf);
	return s;
}

VALUE method_get_seq_starts(VALUE self) {
	VALUE arr, pos;
	FILE *fd;
	int size;
	char buf[BUF_SIZE];
	char block[BUF_SIZE];
	int bptr = 0;
	unsigned int bytepos = 0;
	arr = rb_ary_new();
	pos = rb_ary_new();
	fd = get_io_ptr(self);
	rb_iv_set(self,"@seq_names",arr);
	rb_iv_set(self,"@seq_starts",pos);
	while (size = fread(buf,1,BUF_SIZE,fd)) { // = getc(fd)) != EOF) {
		int i = 0;
		for (i=0;i<size;i++) {
			if (buf[i] == '>') {
				while (++i < size && buf[i] != '\n') {
					// push it onto the existing block
					block[bptr++] = buf[i];
				}
				if (buf[i] == '\n') {
					rb_ary_push(arr, rb_str_new(block,bptr));
					rb_ary_push(pos, UINT2NUM(bytepos+i+1));
					bptr = 0;
				}
			}
		}
		bytepos += size;
	}
	return Qnil;
}

int get_nmer_code(char *seq,int size)
{
	int i;
	uint r = 0;
	for (i=0;i<size;i++) {
		if (seq[i] == 'N') return -1;
		if (seq[i] == 'a' || seq[i] == 'A') r = (r << 2) | 0;
		if (seq[i] == 't' || seq[i] == 'T') r = (r << 2) | 1;
		if (seq[i] == 'g' || seq[i] == 'G') r = (r << 2) | 2;
		if (seq[i] == 'c' || seq[i] == 'C') r = (r << 2) | 3;
	}
	return r;
}

VALUE code_to_nmer(int code,int size)
{
	char buf[512];
	int i;
	const char *c = "ATGC";
	for (i=size-1;i>=0;i--) {
		buf[i] = c[code & 3];
		code = code >> 2;
	}
	return rb_str_new(buf,size);
}

VALUE method_get_nmer_freq(VALUE self, VALUE sq, VALUE nm) {
	int n,i,code;
	int size;
	char *seq;
	int *buf,bsize;
	VALUE h;

	n = NUM2INT(nm);
	bsize = 1<<(n*2);
	buf = ALLOC_N(int,bsize);
	memset(buf,0,bsize*sizeof(int));
	seq = RSTRING_PTR(sq);
	size = RSTRING_LEN(sq);
	for (i=0;i<=size-n;i++) {
		code = get_nmer_code(seq+i,n);
		if (code == -1) continue;
		buf[code]++;
	}
	h = rb_hash_new();
	for (i=0;i<bsize;i++) {
		if (!buf[i]) continue;
		rb_hash_aset( h, code_to_nmer(i,n), INT2NUM(buf[i]) );
	}
	xfree(buf);
	return h;
}
