#ifndef RBX_GRAMMAR_INTERNAL_HPP
#define RBX_GRAMMAR_INTERNAL_HPP

#include <stdbool.h>
#include <string>
#include <list>

#include <quark.h>
#include <bstrlib.h>
#include <ptr_array.h>

#include "parser/local_state.hpp"
#include "prelude.hpp"
#include "object_utils.hpp"

namespace rubinius {
  namespace parser {

#define ID    quark
#define VALUE Object*

    enum lex_state {
        EXPR_BEG,                   /* ignore newline, +/- is a sign. */
        EXPR_END,                   /* newline significant, +/- is a operator. */
        EXPR_ARG,                   /* newline significant, +/- is a operator. */
        EXPR_CMDARG,                /* newline significant, +/- is a operator. */
        EXPR_ENDARG,                /* newline significant, +/- is a operator. */
        EXPR_MID,                   /* newline significant, +/- is a operator. */
        EXPR_FNAME,                 /* ignore newline, no reserved words. */
        EXPR_DOT,                   /* right after `.' or `::', no reserved words. */
        EXPR_CLASS,                 /* immediate after `class', no here document. */
    };

#ifdef HAVE_LONG_LONG
    typedef unsigned LONG_LONG stack_type;
#else
    typedef unsigned long stack_type;
#endif

  }; // namespace parser
}; // namespace rubinius

#include "parser/grammar_node.hpp"

namespace rubinius {
  namespace parser {

    typedef struct rb_parse_state {
      int end_seen;
      int debug_lines;
      int heredoc_end;
      int command_start;
      NODE *lex_strterm;
      int class_nest;
      int in_single;
      int in_def;
      int compile_for_eval;
      ID cur_mid;
      char *token_buffer;
      int tokidx;
      int toksiz;
      int emit_warnings;
      /* Mirror'ing the 1.8 parser, There are 2 input methods,
         from IO and directly from a string. */

      /* this function reads a line from lex_io and stores it in
       * line_buffer.
       */
      bool (*lex_gets)(rb_parse_state*);
      bstring line_buffer;

      /* If this is set, we use the io method. */
      FILE *lex_io;
      /* Otherwise, we use this. */
      bstring lex_string;
      bstring lex_lastline;

      char *lex_pbeg;
      char *lex_p;
      char *lex_pend;
      int lex_str_used;

      enum lex_state lex_state;
      int in_defined;
      stack_type cond_stack;
      stack_type cmdarg_stack;

      void *lval; /* the parser's yylval */

      ptr_array comments;
      int column;
      NODE *top;
      ID *locals;

      LocalState* variables;

      int ternary_colon;

      void **memory_pools;
      int pool_size, current_pool;
      char *memory_cur;
      char *memory_last_addr;
      int memory_size;

      STATE;
      Object* error;

    } rb_parse_state;

#define PARSE_STATE ((rb_parse_state*)parse_state)
#define PARSE_VAR(var) (PARSE_STATE->var)
#define ruby_debug_lines PARSE_VAR(debug_lines)
#define heredoc_end PARSE_VAR(heredoc_end)
#define command_start PARSE_VAR(command_start)
#define lex_strterm PARSE_VAR(lex_strterm)
#define class_nest PARSE_VAR(class_nest)
#define in_single PARSE_VAR(in_single)
#define in_def PARSE_VAR(in_def)
#define compile_for_eval PARSE_VAR(compile_for_eval)
#define cur_mid PARSE_VAR(cur_mid)

#define tokenbuf PARSE_VAR(token_buffer)
#define tokidx PARSE_VAR(tokidx)
#define toksiz PARSE_VAR(toksiz)

  }; // namespace parser
}; // namespace rubinius

#endif
