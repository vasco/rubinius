#include "prelude.hpp"
#include "object.hpp"
#include "vm.hpp"
#include "objectmemory.hpp"
#include "message.hpp"

#include "builtin/array.hpp"
#include "builtin/task.hpp"
#include "builtin/tuple.hpp"
#include "builtin/contexts.hpp"

namespace rubinius {

  Message::Message(STATE, Array* ary) :
      task(NULL), argument_start(0), send_site(NULL), name(NULL),
      recv(Qnil), block(Qnil), splat(Qnil), current_self(Qnil),
      total_args(0), stack(0), start(0), priv(false), lookup_from(NULL), 
      method(NULL), module(NULL) {
    this->state = state;
    arguments = ary;
    total_args = arguments->size();
  }

  Message::Message(STATE) :
      state(state), arguments(NULL), task(NULL),
      argument_start(0), send_site(NULL), name(NULL),
      recv(Qnil), block(Qnil), splat(Qnil), current_self(Qnil),
      total_args(0), stack(0), start(0), priv(false), lookup_from(NULL), 
      method(NULL), module(NULL) { }

  OBJECT Message::get_argument(size_t index) {
    if(arguments) {
      return arguments->get(state, start + index);
    } else if(task) {
      /* recv
       * arg0
       * arg1
       * arg2
       *
       * total_args = 3, index = which you want
       *
       * back 3 is recv, - 1 to get to the first arg
       * - index to get to which argument you want
       */
      return task->active->stack_back(total_args - start - index - 1);
    } else {
      throw Assertion("message not setup properly");
    }
  }

  void Message::set_arguments(STATE, Array* args) {
    arguments = args;
    total_args = args->size();
    start = 0;
  }

  void Message::combine_with_splat(STATE, Task* task, Array* splat) {
    arguments = Array::create(state, splat->size() + total_args);

    import_arguments(state, task, total_args);
    size_t stack_args = total_args;
    total_args += splat->size();

    for(size_t i = 0, n = stack_args; i < total_args; i++, n++) {
      arguments->set(state, n, splat->get(state, i));
    }
  }

  void Message::import_arguments(STATE, Task* task, size_t args) {
    this->task = task;
    if(!arguments) {
      arguments = Array::create(state, args);
    }

    size_t stack_pos = start + args - 1;

    for(size_t i = 0; i < args; i++, stack_pos--) {
      OBJECT arg = task->active->stack_back(stack_pos);
      arguments->set(state, i, arg);
    }

    total_args = args;
  }

  void Message::unshift_argument(STATE, OBJECT val) {
    if(arguments) {
      total_args++;
      if(start > 0) {
        arguments->set(state, --start, val);
      } else {
        arguments->unshift(state, val);
      }
      return;
    }

    arguments = Array::create(state, total_args);

    size_t stack_pos = total_args - start - 1;

    arguments->set(state, 0, val);

    for(size_t i = 1; i <= total_args; i++, stack_pos--) {
      OBJECT arg = task->active->stack_back(stack_pos);
      arguments->set(state, i, arg);
    }

    start = 0;
    total_args++;
  }

  OBJECT Message::shift_argument(STATE) {
    OBJECT first = get_argument(0);
    start++;
    return first;
  }

}