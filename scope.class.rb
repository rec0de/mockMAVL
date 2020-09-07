class Scope

	def initialize
		@stack = [[]]
		@stackIndex = 0
	end

	def defineVal(id, type)
		@stack[@stackIndex].push(ScopeEntry.new(:val, type, id))
	end

	def defineVar(id, type)
		@stack[@stackIndex].push(ScopeEntry.new(:var, type, id))
	end

	def defineFunc(id, type, arguments)
		@stack[@stackIndex].push(ScopeEntry.new(:func, type, id, arguments))
	end

	def descend
		@stack.push([])
		@stackIndex += 1
	end

	def exit
		@stack.pop()
		@stackIndex -= 1
	end

	def thingsOfType(type, recordDefs)
		@stack.flatten.reverse.uniq{ |entry| entry.id }.keep_if{ |entry| entry.hasDataType(type) || (entry.isRecord && recordDefs.recordHasTypeElement(entry.recordId, type))}
	end

	def getVarOrFunc
		@stack.flatten.reverse.uniq{ |entry| entry.id }.keep_if{ |entry| entry.structureType == :var || entry.structureType == :func}.sample
	end

	def getVar
		@stack.flatten.reverse.uniq{ |entry| entry.id }.keep_if{ |entry| entry.structureType == :var }.sample
	end

	def getVectorOrMatrix
		@stack.flatten.reverse.uniq{ |entry| entry.id }.keep_if{ |entry| (entry.dataType.isVector || entry.dataType.isMatrix) && (entry.structureType == :var || entry.structureType == :val) }.sample
	end

	def getFreeVarId(type)
		choice = NameGenerator::varName(type)
		
		while @stack[@stackIndex].index{ |stackEntry| stackEntry.id == choice } != nil
			choice = NameGenerator::varName(type)
		end

		return choice
	end

	def getFreeFuncId(type)
		choice = NameGenerator::funcName(type)
		
		while @stack[@stackIndex].index{ |stackEntry| stackEntry.id == choice } != nil
			choice = NameGenerator::funcName(type)
		end

		return choice
	end

end

class ScopeEntry
	def initialize(type, datatype, id, arguments = [])
		@type = type
		@datatype = datatype
		@id = id
		@arguments = arguments
	end

	def hasDataType(dtype)
		@datatype == dtype
	end

	def dataType
		@datatype
	end

	def id
		@id
	end

	def structureType
		@type
	end

	def arguments
		@arguments
	end

	def isRecord
		@datatype.isRecord
	end

	def recordId
		if @datatype.isRecord
			return @datatype.id
		end
	end
end

class RecordDefinitions
	def initialize
		@map = {}
	end

	def define(id, types, names, isVarFlags)
		@map[id] = [types, names, isVarFlags]
	end

	def getTypes(id)
		@map[id][0]
	end

	def getNames(id)
		@map[id][1]
	end

	def recordHasTypeElement(id, type)
		@map[id][0].each{ |rtype|
			return true if type == rtype
		}
		return false
	end

	def recordHasVarElement(id)
		@map[id][2].each{ |varflag|
			return true if varflag
		}
		return false
	end

	def randomVarElementOfRecord(id)
		index = (0...@map[id][0].length).select{ |i| @map[id][2][i]}.sample
		return [@map[id][0][index], @map[id][1][index]]
	end

	def haveRecord
		@map.length > 0
	end

	def exists(id)
		@map.key?(id)
	end

	def randomRecord
		id = @map.keys.sample
		return Type.new(:record, 0, 0, id)
	end
end

class NameGenerator
	@@intNames = [
		[["i", "j", "k", "l", "m", "n", "res", "value", "arg"]],
		[["stack", "system", "process", "event", "queue", "list"], ["count", "counter", "amount", "depth"]]
	]
	@@floatNames = [
		[["w", "x", "y", "z", "res", "arg", "value"]],
		[["calculated", "random", "data", "precise", "sin", "cos", "pow"], ["amount", "frac", "flt", "value"]]
	]
	@@booleanNames = [
		[["is", "can", "will"], ["load", "save", "read", "write", "exec"]],
		[["config", "system", "send", "read", "write", "exec", "restore", "ready", "pause", "state", "process", "storage"], ["toggle", "flag", "enabled", "override"]],
		[["is", "has"], ["loaded", "saveed", "done", "ready"]]
	]
	@@stringNames = [
		[["customer", "object", "target", "uri", "service", "storage"], ["name", "data", "value", "location", "address", "properties"]],
		[["match", "regex", "search", "query"], ["type", "pattern", "name", "term"]]
	]
	@@vectorNames = [
		[["shift", "scale", "bit", "data"], ["vector", "list", "array"]]
	]
	@@matrixNames = [
		[["rotation", "transformation", "affine", "data", "bit", "translation"], ["matrix", "field", "array"]]
	]
	@@recordNames = [
		[["data", "client", "server", "packet", "io"], ["object", "representation", "struct", "unit", "node"]],
		[["packet", "person", "message", "tree", "node"]]
	]
	@@funcNames = [
		[["apply", "trigger", "flush", "reset"], ["changes", "updates", "reload", "state"]],
		[["call", "visit", "trigger"], ["listener", "external", "visitor", "modifier"]]
	]
	@@funcModifiers = ["read", "get", "calculate", "fetch", "retrieve", "update", "refresh", "construct", "build"]

	def self.varName(type)
		if type.isVector
			return self.pickFrom(@@vectorNames)
		elsif type.isMatrix
			return self.pickFrom(@@matrixNames)
		elsif type.isBool
			return self.pickFrom(@@booleanNames)
		elsif type.isInt
			return self.pickFrom(@@intNames)
		elsif type.isFloat
			return self.pickFrom(@@floatNames)
		elsif type.isRecord
			return self.pickFrom(@@recordNames)
		else
			return self.pickFrom(@@stringNames)
		end
	end

	def self.funcName(type)
		if type.isVoid
			return self.pickFrom(@@funcNames)
		else
			return @@funcModifiers.sample + (vname=self.varName(type))[0].capitalize + vname[1..-1]
		end
	end

	def self.pickFrom(nameArray)
		generated = nameArray.sample.map.with_index{ |field, i| i > 0 ? field.sample.capitalize : field.sample }
		return generated.join('')
	end
end