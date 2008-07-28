#include "environment.hpp"
#include "compiled_file.hpp"
#include "probes.hpp"

#include <iostream>
#include <fstream>
#include <string>

namespace rubinius {
  Environment::Environment() {
    state = new VM();
    state->probe = new TaskProbe;
  }

  Environment::~Environment() {
    delete state;
  }

  void Environment::load_argv(int argc, char** argv) {
    state->set_const("ARG0", String::create(state, argv[0]));

    Array* ary = Array::create(state, argc - 1);
    for(int i = 0; i < argc - 1; i++) {
      ary->set(state, i, String::create(state, argv[i + 1]));
    }

    state->set_const("ARGV", ary);
  }

  void Environment::load_directory(std::string dir) {
    std::string path = dir + "/.load_order.txt";
    std::ifstream stream(path.c_str());
    if(!stream) throw std::runtime_error("Unable to load directory");

    std::string line;

    while(!stream.eof()) {
      stream >> line;
      std::cout << "Loading: " << line << std::endl;
      run_file(dir + "/" + line);
    }
  }

  void Environment::run_file(std::string file) {
    std::ifstream stream(file.c_str());
    if(!stream) throw std::runtime_error("Unable to open file to run");

    CompiledFile* cf = CompiledFile::load(stream);
    if(cf->magic != "!RBIX") throw std::runtime_error("Invalid file");

    // TODO check version number
    cf->execute(state);
  }
}