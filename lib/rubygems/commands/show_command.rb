require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/version_option'

class Gem::Commands::ShowCommand < Gem::Command

  include Gem::LocalRemoteOptions
  include Gem::VersionOption

  def initialize
    Gem.load_yaml

    super 'show', 'Show gem summary',
          :domain => :local, :version => Gem::Requirement.default

    add_version_option('examine')
    add_platform_option

    add_local_remote_options
  end

  def arguments # :nodoc:
    <<-ARGS
GEMFILE       name of gem to show for
    ARGS
  end

  def defaults_str # :nodoc:
    "--local --version '#{Gem::Requirement.default}'"
  end

  def usage # :nodoc:
    "#{program_name} [GEMFILE]"
  end

  def execute
    specs = []
    gem = options[:args].shift

    unless gem then
      raise Gem::CommandLineError,
            "Please specify a gem name or file on the command line"
    end

    dep = Gem::Dependency.new gem, options[:version]

    if local? then
      if specs.empty? then
        specs.push(*dep.matching_specs)
      end
    end

    if remote? then
      found = Gem::SpecFetcher.fetcher.fetch dep

      specs.push(*found.map { |spec,| spec })
    end

    if specs.empty? then
      alert_error "Unknown gem '#{gem}'"
      terminate_interaction 1
    end

    specs.each do |s|
      [:name, :version, :authors, :description, :homepage].each do |key|
        val = s.send(key)
        next unless val
        val = val.join(', ') if val.is_a?(Array)
        say sprintf("%-#{INDENTWIDTH}s%s", "#{key}:", fold(val))
      end

      if deps = s.send(:dependencies) and !deps.empty?
        say 'dependency:  ' + fold(deps.map{|x|x.name}.join(', '))
      end
    end
  end

  LINEWIDTH = 80
  INDENTWIDTH = 'description: '.size
  INDENT = ' ' * INDENTWIDTH
  CONTENTWIDTH = LINEWIDTH - INDENTWIDTH

  # this assumes all characters are narrow (halfwidth)
  def fold(str)
    lines = []
    line = nil
    str = str.to_s
    str.gsub!(/&(?:(\w+)|#(?:x([0-9a-fA-F]+)|(\d+)));/) do
      if $1
        case $1.downcase
        when 'amp';  '&'
        when 'lt';   '<'
        when 'gt';   '>'
        when 'quot'; '"'
        else;        $&
        end
      elsif $2
        [$2.to_i(16)].pack("U")
      else
        [$3.to_i].pack("U")
      end rescue $&
    end
    str.split.each do |word|
      if line.nil?
        line = word
      elsif CONTENTWIDTH < line.size + word.size
        lines << line
        line = word
      else
        line << ' ' << word
      end
    end
    lines << line
    lines.join("\n" + INDENT)
  end
end
