#include "builtin/nativemethod.hpp"
#include "capi/handle.hpp"

#include "capi/ruby.h"

namespace rubinius {
  namespace capi {
    void Handle::free_data() {
      if(as_.cache_data) {
        switch(type_) {
        case cRArray:
          delete[] as_.rarray->dmwmb;
          delete as_.rarray;
          break;
        case cRString:
          delete[] as_.rstring->dmwmb;
          delete as_.rstring;
          break;
        case cRFloat:
          delete as_.rfloat;
          break;
        default:
          break;
        }
        as_.cache_data = 0;
      }

      type_ = cUnknown;
    }

    void Handle::debug_print() {
      std::cerr << std::endl << "Invalid handle usage detected!" << std::endl;
      std::cerr << "  handle:     " << this << std::endl;
      std::cerr << "  checksum:   0x" << std::hex << checksum_ << std::endl;
      std::cerr << "  references: " << references_ << std::endl;
      std::cerr << "  type:       " << type_ << std::endl;
      std::cerr << "  object:     " << object_ << std::endl;
    }

    Handle::~Handle() {
      free_data();
      invalidate();
    }
  }
}
