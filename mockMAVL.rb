require_relative 'generator.class'

helptext = ['Usage:', 'ruby mockMAVL.rb [options]', '',
			'Options:',
			'--pretty "pretty" print, tries to insert some newlines and performs minor whitespace cleanup',
			'--maxdim=6 Set maximum vector and matrix dimension',
			'--help (-h) Show this help and exit',
			''
		]

generator = MockMAVL.new

# Parse command line options
ARGV.each do|a|
	if a == '--pretty' then
		$prettyprint = true
	elsif a =~ /^--maxdim=/ then
		generator.setMaxDim(a[9..-1].to_i)
	elsif a == '-h' or a == '--help' then
		helptext.each{|line| puts line}
		exit
	elsif a[0] == '-' then
		STDERR.puts("[ERROR] Unknown option '"+a+"'")
		exit
	end
end

generated = generator.generateModule()

puts $prettyprint ? MockMAVL::prettyPrint(generated) : generated