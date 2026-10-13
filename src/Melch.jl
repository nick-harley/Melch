module Melch

using DataStructures, DataFrames, JLD2

using Chakra

export id

# Abstract types
# Identifiers are the names of constituents 
# Constituents are data structures which contain information
# Hierarchy is the type of CHAKRA knowledge structures

abstract type Id <: Chakra.Id end

abstract type Constituent <: Chakra.Constituent end

abstract type Hierarchy <: Chakra.Hierarchy end


# The concrete types for Identifiers

struct DatasetId <: Id

    # TYPE OF DATASET IDENTIFIERS
    
    dataset::Int
end

struct MelodyId <: Id

    # TYPE OF MELODY IDENTIFIERS
    
    dataset::Int
    melody::Int
end

struct EventId <: Id

    # TYPE OF EVENT (NOTE) IDENTIFIERS
    
    dataset::Int
    melody::Int
    event::Int
end

# helper function for constructing identifiers
id(d::Int) = DatasetId(d)
id(d::Int,m::Int) = MelodyId(d,m)
id(d::Int,m::Int,e::Int) = EventId(d,m,e)
id(d::DatasetId,i::Int) = id(d.dataset,i)
id(m::MelodyId,i::Int) = id(m.dataset,m.melody,i)
id(d::DatasetId,m::Int,i::Int) = id(d.dataset,m,i)

# helper function to write ids to strings
idtostring(e::EventId) = string(e.dataset,"/",e.melody,"/",e.event)
idtostring(e::MelodyId) = string(e.dataset,"/",e.melody)
idtostring(e::DatasetId) = string(e.dataset)

# CONCRETE TYPES FOR CONSTITUENTS

mutable struct Event <: Constituent

    # TYPE OF MUSICAL EVENTS (NOTES)

    id::EventId
    ONSET::Option{Int}
    DELTAST::Option{Int}
    BIOI::Option{Int}
    DUR::Option{Int}
    CPITCH::Option{Int}
    MPITCH::Option{Int}
    ACCIDENTAL::Option{Int}
    KEYSIG::Option{Int}
    MODE::Option{Int}
    BARLENGTH::Option{Int}
    PULSES::Option{Int}
    PHRASE::Option{Int}
    VOICE::Option{Int}
    ORNAMENT::Option{Int}
    COMMA::Option{Int}
    VERTINT12::Option{Int}
    ARTICULATION::Option{Int}
    DYN::Option{Int}

end

# helper function for creating "empty" events 
# (none is chakra constant for a missing value)
Event(x) = Event(x,none,none,none,none,none,none,none,none,none,
                 none,none,none,none,none,none,none,none,none)

struct Melody <: Constituent

    # TYPE OF MUSICAL MELODIES

    id::MelodyId
    events::Vector{Event}
    description::String
end

Melody(x,desc) = Melody(x,Event[],desc)

struct Dataset <: Constituent

    # TYPE OF MELODY DATASETS

    id::DatasetId
    melodies::Vector{Melody}
    description::String
end

Dataset(x,desc) = Dataset(x,Melody[],desc)

# CONCRETE TYPE FOR CHAKRA HIERARCHIES

struct Corpus <: Hierarchy

    # TYPE OF MELODY CORPORA
    
    datasets::Vector{Dataset}
    description::String
end

# Helper function for creating empty corpus
Corpus(desc) = Corpus(Dataset[],desc)


# MELCH ATTRIBUTES

# This defines a mapping from symbols (attribute names) to types. 
__attributes__(::Val{a}) where a = error("Attribtue $a is not defined in Melch.")
__attributes__(a::Symbol) = __attributes__(Val{a}())

# Map each symbol to the type of its values. 
__attributes__(::Val{:ONSET}) = Int
__attributes__(::Val{:DELTAST}) = Int
__attributes__(::Val{:BIOI}) = Int
__attributes__(::Val{:DUR}) = Int
__attributes__(::Val{:CPITCH}) = Int
__attributes__(::Val{:MPITCH}) = Int
__attributes__(::Val{:ACCIDENTAL}) = Int
__attributes__(::Val{:KEYSIG}) = Int
__attributes__(::Val{:MODE}) = Int
__attributes__(::Val{:BARLENGTH}) = Int
__attributes__(::Val{:PULSES}) = Int
__attributes__(::Val{:PHRASE}) = Int
__attributes__(::Val{:VOICE}) = Int
__attributes__(::Val{:ORNAMENT}) = Int
__attributes__(::Val{:COMMA}) = Int
__attributes__(::Val{:VERTINT12}) = Int
__attributes__(::Val{:ARTICULATION}) = Int
__attributes__(::Val{:DYN}) = Int

struct Attribute{N,T} <: Chakra.Attribute{N,T}

    # CONCRETE TYPE OF ATTRIBUTE NAMES
    
    Attribute(a::Symbol) = new{a,__attributes__(a)}()
end

# These lines make Melch Attributes destructions available outside of Melch. 
Chakra.__attributes__(::Val{Symbol("Melch.CPITCH")}) = Attribute(:CPITCH)
Chakra.__attributes__(::Val{Symbol("Melch.DUR")}) = Attribute(:DUR)

# These lines define constants for each attribute name. 
ONSET = Attribute(:ONSET)
DELTAST = Attribute(:DELTAST)
BIOI = Attribute(:BIOI)
DUR = Attribute(:DUR)
CPITCH = Attribute(:CPITCH)
MPITCH = Attribute(:MPITCH)
ACCIDENTAL = Attribute(:ACCIDENTAL)
KEYSIG = Attribute(:KEYSIG)
MODE = Attribute(:MODE)
BARLENGTH = Attribute(:BARLENGTH)
PULSES = Attribute(:PULSES)
PHRASE = Attribute(:PHRASE)
VOICE = Attribute(:VOICE)
ORNAMENT = Attribute(:ORNAMENT)
COMMA = Attribute(:COMMA)
VERTINT12 = Attribute(:VERTINT12)
ARTICULATION = Attribute(:ARTICULATION)
DYN = Attribute(:DYN)

####################
# CHAKRA INTERFACE #
####################

# These functions from Chakra must be overloaded for client applications (such as Idyoms) to work. 

# pts must be defined for each concrete constituent type 
Chakra.pts(d::Dataset) = [id(d.id,i) for i in 1:length(d.melodies)]
Chakra.pts(m::Melody) = [id(m.id,i) for i in 1:length(m.events)]
Chakra.pts(e::Event) = Id[]

# geta (get attribute) must be defined for each attribute and each constituent type
Chakra.geta(::Attribute{a,T},d::Dataset) where {a,T} = none
Chakra.geta(::Attribute{a,T},m::Melody) where {a,T} = none
Chakra.geta(::Attribute{a,T},e::Event) where {a,T} = Base.getproperty(e,a)

# fnd must be defined for each identifier type and each hierarchy type
Chakra.fnd(x::DatasetId,c::Corpus) = Base.get(c.datasets,x.dataset+1,none)
Chakra.fnd(x::MelodyId,c::Corpus) = obind(fnd(id(x.dataset),c), d -> Base.get(d.melodies,x.melody,none))
Chakra.fnd(x::EventId,c::Corpus) = obind(fnd(id(x.dataset,x.melody),c), m -> Base.get(m.events,x.event,none))


# LOADING THE CONCRETE MELCH DATA

function parse_file(x,filepath)

    # PARSE A LISP FILE TO A DATASET CONSTITUENT
    
    f = open(filepath)
    s = read(f,String)
    
    dataset_description = s[3:findfirst(".",s)[1]]
    
    dataset = Dataset(x,dataset_description)
    
    s = replace(s,"\n " => "","  " => "", ") ("=>")(")[1:end-1]
    
    melody_strings = String[]
    melody_descriptions = String[]

    # get melody strings and descriptions
    for (i,m) in enumerate(split(s,"(\"")[3:end])
        
        b = findfirst("((",m)[2]+1
        e = findlast("))",m)[1]-2
        push!(melody_strings,m[b:e])
        
        melody_description = string(m[1:findfirst("\"",m)[1]-1])                
        push!(melody_descriptions,melody_description)
    end

    # get event strings
    for (m,mstring) in enumerate(melody_strings)
        
        melody = Melody(id(x,m),melody_descriptions[m])

        event_strings = split(mstring,")) ((")
        
        for (e,event_string) in enumerate(event_strings)

            event = Event(id(x,m,e))
            
            att_strings = split(event_string,")(")
            
            for astring in att_strings
                key_val = split(astring," ")
                k = Symbol(key_val[1][2:end])
                v = (v = key_val[2]; v == "NIL" ? none : parse(Int,v))
                setproperty!(event,k,v)
            end

            push!(melody.events,event)
            
        end

        push!(dataset.melodies,melody)
        
    end

    return dataset

end

# The __data__ constant must be set to a Chakra.Hierarchy containing the knowledge 
# Here, we set it to an empty corpus hierarchy (called Melch). The __INIT__ function below will populate this hierarchy. 
__data__ = Corpus("Melch")

function __INIT__(path)

    # TAKES PATH TO CONCRETE DATA AS ARGUMENT
    # PARSES ALL THE LISP FILES AND ADDS EACH DATA SET TO THE __data__ HIERARCHY

    # NOTE: 21.lisp doesn't parse. is there a missing bracket somewhere? also han0953 has not events. 

    for i in [0:20...,22:25...]
        filename = "$i.lisp"
        filepath = joinpath(path,filename)
        dataset = parse_file(id(i),filepath)
        push!(__data__.datasets,dataset)
    end

end


# DISPLAY USING DATAFRAMES
# These are just helpful functions that allow you to tabulate the data

function event_to_df(e::Event)

    # EVENT TO DATAFRAME
    
    return DataFrame(OrderedDict(fieldnames(Event) .=> getfield.(Ref(e), fieldnames(Event))))
end

function melody_to_df(m::Melody)

    # MELODY TO DATAFRAME
    
    return vcat(event_to_df.(m.events)...)
end

end
