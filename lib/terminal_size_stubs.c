#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

#if defined(__unix__) || defined(__APPLE__)
#include <sys/ioctl.h>
#include <unistd.h>
#endif

CAMLprim value ofzf_terminal_size_ioctl(value fd_value) {
  CAMLparam1(fd_value);
  CAMLlocal2(pair, some);
#if defined(TIOCGWINSZ)
  struct winsize size;
  int fd = Int_val(fd_value);

  if (ioctl(fd, TIOCGWINSZ, &size) == 0 && size.ws_row > 0 && size.ws_col > 0) {
    pair = caml_alloc_tuple(2);
    Store_field(pair, 0, Val_int(size.ws_row));
    Store_field(pair, 1, Val_int(size.ws_col));
    some = caml_alloc(1, 0);
    Store_field(some, 0, pair);
    CAMLreturn(some);
  }
#endif
  CAMLreturn(Val_none);
}
