#include "ruby.h"
#include "ruby/io.h"
#include "stdio.h"
#include <string.h>
#include <strings.h>

VALUE Fcs3Aux = Qnil;

VALUE method_read_fcs_header(VALUE self);
VALUE method_get_text(VALUE self);
VALUE method_get_data(VALUE self);
void Init_fcs3_aux();
//VALUE method_get_seq_chunk(VALUE self, VALUE pos1, VALUE pos2);

FILE *get_io_ptr(VALUE self) {
	VALUE io;
	io = rb_iv_get(self,"@io");
	return rb_io_stdio_file(RFILE(io)->fptr);
}

void Init_fcs3_aux() {
	Fcs3Aux = rb_define_module("Fcs3Aux");
	rb_define_method(Fcs3Aux, "read_fcs_header", method_read_fcs_header, 0);
	rb_define_method(Fcs3Aux, "get_text", method_get_text, 0);
	rb_define_method(Fcs3Aux, "get_data", method_get_data, 0);
}

#define BUF_SIZE 1200 // should be at least large enough to hold a >chr line

typedef struct {
	char format[6];
	char space[4];
	char text_start[8];
	char text_end[8];
	char data_start[8];
	char data_end[8];
	char analysis_start[8];
	char analysis_end[8];
} Fcs3Header;

VALUE method_read_fcs_header(VALUE self) {
	FILE *fd;
	int size;
	Fcs3Header header;

	fd = get_io_ptr(self);
	size = fread(&header,1,sizeof(header),fd);

	rb_iv_set(self, "@format", rb_str_new(header.format,6) );
	rb_iv_set(self, "@text_start", rb_str_new(header.text_start,8) );
	rb_iv_set(self, "@text_end", rb_str_new(header.text_end,8) );
	rb_iv_set(self, "@data_start", rb_str_new(header.data_start,8) );
	rb_iv_set(self, "@data_end", rb_str_new(header.data_end,8) );
	rb_iv_set(self, "@analysis_start", rb_str_new(header.analysis_start,8) );
	rb_iv_set(self, "@analysis_end", rb_str_new(header.analysis_end,8) );
	return Qnil;
}

VALUE method_get_text(VALUE self) {
	FILE *fd;
	fd = get_io_ptr(self);
	unsigned int start, end;
	char *buf, *head, *token;
	char delim;
	VALUE s, key, value;

	start = NUM2UINT(rb_iv_get(self,"@text_start"));
	end = NUM2UINT(rb_iv_get(self,"@text_end"));

	fseek(fd,start,SEEK_SET);
	buf = ALLOC_N(char,end-start+1);
	fread(buf,1,end-start+1,fd);
	delim = buf[0];
	//s = rb_str_new(buf,end-start+1);
	s = rb_hash_new();
	head = buf+1;
	while( *head && (token = index(head,delim))) {
		key = rb_str_new(head, token - head);
		head = token+1;
		token = index(head,delim);
		while(token[1] == delim) token = index(token+2,delim);
		value = rb_str_new(head, token - head);
		rb_hash_aset( s, key, value );
		head = token + 1;
	}
	xfree(buf);
	return s;
}

VALUE method_get_data(VALUE self) {
	unsigned int start, end;
	char *buf, *head, *token;
	VALUE s;
	FILE *fd = get_io_ptr(self);

	start = NUM2UINT(rb_iv_get(self,"@data_start"));
	end = NUM2UINT(rb_iv_get(self,"@data_end"));

	fseek(fd,start,SEEK_SET);
	buf = ALLOC_N(char,end-start+1);
	fread(buf,1,end-start+1,fd);
	VALUE _datatype;
	s = rb_str_new(buf,end-start+1);
	xfree(buf);
	return rb_funcall(self, rb_intern("unpack_data"), 1, s);
}
