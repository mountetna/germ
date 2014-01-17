#include "ruby.h"
#include "ruby/io.h"
#include "stdio.h"
#include <string.h>
#include <ctype.h>

VALUE HashTableAux = Qnil;

VALUE method_load_file(VALUE self, VALUE file);

void Init_hash_table_aux();

void Init_hash_table_aux() {
	HashTableAux = rb_define_module("HashTableAux");
	rb_define_method(HashTableAux, "load_file", method_load_file, 1);
}

#define BUF_SIZE 1200

long get_file_size(FILE *fp)
{
	long fp_size;
	fseek(fp, 0, SEEK_END);
	fp_size = ftell(fp);
	rewind(fp);
	return fp_size;
}
char *get_file_contents(FILE *fp,long fp_size)
{
	char *contents;
	contents = ALLOC_N(char,fp_size);
	fread(contents,sizeof(char), fp_size, fp);
	return contents;
}

VALUE get_token_array(char *buf,const char *sep) {
	char *token;
	VALUE ary = rb_ary_new();

	token = strtok(buf,sep);
	while( token != NULL )
	{
		rb_ary_push(ary, rb_str_new2(token));
		token = strtok(NULL,sep);
	}
	return ary;
}

VALUE convert_to_symbols(VALUE ary) {
	int i;
	for (i=0;i<RARRAY_LEN(ary);i++) {
		rb_ary_store( ary, i, ID2SYM( rb_intern_str(rb_ary_entry(ary,i)) ) );
	}
	return ary;
}
#define TYPE_INT 0
#define TYPE_FLOAT 1
#define TYPE_SYM 2
#define TYPE_HASH 3
unsigned int convert_types[10];
void set_convert_types()
{
	convert_types[TYPE_INT] = rb_intern("int");
	convert_types[TYPE_FLOAT] = rb_intern("float");
	convert_types[TYPE_SYM] = rb_intern("sym");
}

char *make_cstr(VALUE s) {
	char *p = ALLOC_N(char,RSTRING_LEN(s)+1);
	MEMCPY(p,RSTRING_PTR(s),char,RSTRING_LEN(s));
	p[RSTRING_LEN(s)] = '\0';
	return p;
}

char *strip_space_quotes( char *o, int len )
{
	char *vf;
	char *c = o;
	char *d;
	int iq = 0;
	if (!c) return 0;
	vf = ALLOC_N(char,len+1);
	d = vf;
	while(isspace(*c)) c++;
	if (*c == '"' || *c == '\'') { c++; iq = 1; }
	while(*c) *d++ = *c++;
	// you hit the end, rewind spaces and quotes
	if (d == vf) {
		xfree(vf);
		return 0;
	}
	while(isspace(*(d-1))) d--;
	if (iq && *(d-1) == '"' || *(d-1) == '\'') d--;
	*d = 0;
	return vf;
}

void make_hash_entry( VALUE h, VALUE s, char *sep )
{
	char *p = make_cstr(s);
	char *kf;
	VALUE key;
	char *vs;

	kf = strip_space_quotes(strtok(p,sep), RSTRING_LEN(s));
	if (!kf) return;
	key = ID2SYM( rb_intern(kf) );
	vs = strtok(NULL,sep);

	if (!vs) {
		rb_hash_aset( h, key, Qnil );
	} else {
		char *vf = strip_space_quotes(vs, RSTRING_LEN(s));
		if (!vf)
			rb_hash_aset( h, key, Qnil );
		else {
			rb_hash_aset( h, key, rb_str_new2(vf) );
			xfree(vf);
		}
	}
	xfree(kf);
	xfree(p);
}

VALUE convert_to_type( VALUE v, VALUE type )
{
	if (type == Qnil || v == Qnil) return v;
	// return the matching type, assuming v is a string
	if (TYPE(type) == T_ARRAY) // it's a hash array
	{
		// tokenize the value based on the first and last characters
		char *p = make_cstr(v);
		char *t1 = make_cstr( rb_ary_entry( type, 0 ) );
		char *t2 = make_cstr( rb_ary_entry( type, 1 ) );
		int i;
		VALUE h = rb_hash_new();
		VALUE ary = get_token_array(p,t1);
		for (i=0;i< RARRAY_LEN(ary); i++) {
			make_hash_entry( h, rb_ary_entry( ary, i ), t2 );
		}
		xfree(p);
		xfree(t1);
		xfree(t2);
		return h;
	}
	else if (SYM2ID(type) == convert_types[TYPE_INT]) {
		char *p = make_cstr(v);
		int i = atoi(p);
		xfree(p);
		return INT2NUM(i);
	}
	else if (SYM2ID(type) == convert_types[TYPE_FLOAT]) {
		char *p = make_cstr(v);
		double f = atof(p);
		xfree(p);
		return DBL2NUM(f);
	}
	else if (SYM2ID(type) == convert_types[TYPE_SYM]) {
		return ID2SYM( rb_intern_str(v) );
	}
	return v;
}

void add_hash_line(VALUE lines, VALUE header, VALUE types, VALUE ary) {
	VALUE hash = rb_hash_new();
	int i;
	for (i=0;i<RARRAY_LEN(header);i++) {
		if (types == Qnil)
			rb_hash_aset( hash, rb_ary_entry(header,i), rb_ary_entry(ary,i) );
		else
			rb_hash_aset( hash, rb_ary_entry(header,i), 
				convert_to_type( rb_ary_entry(ary,i), rb_ary_entry( types, i ) )
			);
	}
	rb_ary_push(lines, hash);
}


VALUE method_load_file(VALUE self, VALUE file) {
	VALUE cmmt = rb_iv_get(self,"@comment");
	char *comment = (cmmt == Qnil) ? 0 : RSTRING_PTR(cmmt);
	int commentsize = (cmmt == Qnil) ? 0 : (RSTRING_LEN(cmmt));

	FILE *fp = fopen(RSTRING_PTR(file),"r");
	long fp_size = get_file_size(fp);
	char *contents = get_file_contents( fp, fp_size );

	VALUE header = rb_iv_get(self,"@header");
	VALUE types = rb_iv_get(self,"@types");


	char *buf = ALLOC_N(char,fp_size);
	int i = 0;
	char *c;
	VALUE ary;
	VALUE lines = rb_ary_new();

	set_convert_types();
	while(i < fp_size) {
		c = buf;
		while(i < fp_size && contents[i] != '\n') *c++ = contents[i++];
		if (i < fp_size) i++;
		*c = 0;
		if (comment && !strncmp(buf,comment,commentsize)) continue;
		// okay, now you can split your string into tokens and push it onto an
		// array.
		ary = get_token_array(buf,"\t");
		if (header == Qnil) {
			header = convert_to_symbols(ary);
			rb_iv_set(self,"@header",header);
			continue;
		}
		add_hash_line( lines, header, types, ary );
	}
	
	rb_iv_set(self,"@lines",lines);
	xfree(buf);
	xfree(contents);
	return Qnil;
}
