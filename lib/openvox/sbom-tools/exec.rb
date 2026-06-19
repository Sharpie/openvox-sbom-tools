require_relative '../sbom-tools'

module OpenVox::SBOMTools
  module Exec
    module_function

    def exec(*command_line, workdir: nil)
      out = StringIO.new
      out_r, out_w = IO.pipe

      opts = {out: out_w, err: $stderr}
      opts[:chdir] = workdir unless workdir.nil?

      pid = Process.spawn(*command_line, opts)

      out_w.close
      reader = Thread.new do
        while line = out_r.gets
          out << line
        end
      end

      Process.wait(pid)
      reader.join

      out.string
    end
  end
end
