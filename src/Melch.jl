module Melch

using DataStructures, DataFrames, JLD2

using Chakra

export id

################
# CONSTITUENTS #
################

abstract type Id <: Chakra.Id end

abstract type Constituent <: Chakra.Constituent end

abstract type Hierarchy <: Chakra.Hierarchy end


###############
# IDENTIFIERS #
###############

struct DatasetId <: Id
    dataset::Int
end

struct MelodyId <: Id
    dataset::Int
    melody::Int
end

struct EventId <: Id
    dataset::Int
    melody::Int
    event::Int
end

id(d::Int) = DatasetId(d)
id(d::Int,m::Int) = MelodyId(d,m)
id(d::Int,m::Int,e::Int) = EventId(d,m,e)
id(d::DatasetId,i::Int) = id(d.dataset,i)
id(m::MelodyId,i::Int) = id(m.dataset,m.melody,i)
id(d::DatasetId,m::Int,i::Int) = id(d.dataset,m,i)

idtostring(e::EventId) = string(e.dataset,"/",e.melody,"/",e.event)
idtostring(e::MelodyId) = string(e.dataset,"/",e.melody)
idtostring(e::DatasetId) = string(e.dataset)





mutable struct Event <: Constituent

    # TYPE OF MUSICAL EVENTS

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

###############
# HIERARCHIES #
###############

struct Corpus <: Hierarchy

    # TYPE OF MELODY CORPORA
    
    datasets::Vector{Dataset}
    description::String
end

Corpus(desc) = Corpus(Dataset[],desc)




__attributes__(::Val{a}) where a = error("Attribtue $a is not defined in Melch.")
__attributes__(a::Symbol) = __attributes__(Val{a}())

struct Attribute{N,T} <: Chakra.Attribute{N,T}
    Attribute(a::Symbol) = new{a,__attributes__(a)}()
end

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

Chakra.__attributes__(::Val{Symbol("Melch.CPITCH")}) = Attribute(:CPITCH)
Chakra.__attributes__(::Val{Symbol("Melch.DUR")}) = Attribute(:DUR)

CPITCH = Attribute(:CPITCH)
DUR = Attribute(:DUR)

####################
# CHAKRA INTERFACE #
####################

Chakra.pts(d::Dataset) = [id(d.id,i) for i in 1:length(d.melodies)]
Chakra.pts(m::Melody) = [id(m.id,i) for i in 1:length(m.events)]
Chakra.pts(e::Event) = Id[]

Chakra.geta(::Attribute{a,T},d::Dataset) where {a,T} = none
Chakra.geta(::Attribute{a,T},m::Melody) where {a,T} = none
Chakra.geta(::Attribute{a,T},e::Event) where {a,T} = Base.getproperty(e,a)

Chakra.geta(a::Symbol,c::Constituent) = Chakra.geta(Attribute(a),c)

Chakra.fnd(x::DatasetId,c::Corpus) = Base.get(c.datasets,x.dataset+1,none)
Chakra.fnd(x::MelodyId,c::Corpus) = obind(fnd(id(x.dataset),c), d -> Base.get(d.melodies,x.melody,none))
Chakra.fnd(x::EventId,c::Corpus) = obind(fnd(id(x.dataset,x.melody),c), m -> Base.get(m.events,x.event,none))






# LOADING

function parse_file(x,filepath)

    # PARSE LISP FILE TO DATASET
    
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


__data__ = Corpus("Melch")

function __INIT__(path)

    # PARSE ALL THE LISP FILES TO A CORPUS

    # NOTE: 21.lisp doesn't parse. is there a missing bracket somewhere? also han0953 has not events. 

    for i in [0:20...,22:25...]
        filename = "$i.lisp"
        filepath = joinpath(path,filename)
        dataset = parse_file(id(i),filepath)
        push!(__data__.datasets,dataset)
    end

end


# DISPLAY USING DATAFRAMES

function event_to_df(e::Event)

    # EVENT TO DATAFRAME
    
    return DataFrame(OrderedDict(fieldnames(Event) .=> getfield.(Ref(e), fieldnames(Event))))
end

function melody_to_df(m::Melody)

    # MELODY TO DATAFRAME
    
    return vcat(event_to_df.(m.events)...)
end

end
