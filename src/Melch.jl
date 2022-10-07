module Melch

using DataStructures, DataFrames, JLD2

using Chakra

export id

################
# CONSTITUENTS #
################

abstract type Id end

abstract type Constituent end

abstract type Hierarchy end




mutable struct Event <: Constituent

    # TYPE OF MUSICAL EVENTS
    
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

Event() = Event(none,none,none,none,none,none,none,none,none,
                none,none,none,none,none,none,none,none,none)

struct Melody <: Constituent

    # TYPE OF MUSICAL MELODIES
    
    events::Vector{Event}
    description::String
end

Melody(desc) = Melody(Event[],desc)

struct Dataset <: Constituent

    # TYPE OF MELODY DATASETS
    
    melodies::Vector{Melody}
    description::String
end

Dataset(desc) = Dataset(Melody[],desc)

###############
# HIERARCHIES #
###############

struct Corpus <: Hierarchy

    # TYPE OF MELODY CORPORA
    
    datasets::Vector{Dataset}
    description::String
end

Corpus(desc) = Corpus(Dataset[],desc)


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

idtostring(e::EventId) = string(e.dataset,"/",e.melody,"/",e.event)
idtostring(e::MelodyId) = string(e.dataset,"/",e.melody)
idtostring(e::DatasetId) = string(e.dataset)

#############
# UTILITIES #
#############

function parse_file(filepath)

    # PARSE LISP FILE TO DATASET
    
    f = open(filepath)
    s = read(f,String)
    
    dataset_description = s[3:findfirst(".",s)[1]]
    
    dataset = Dataset(dataset_description)
    
    s = replace(s,"\n " => "","  " => "", ") ("=>")(")[1:end-1]
    
    melody_strings = String[]
    melody_descriptions = String[]

    # get melody strings
    for (i,m) in enumerate(split(s,"(\"")[3:end])
        
        b = findfirst("((",m)[2]+1
        e = findlast("))",m)[1]-2
        push!(melody_strings,m[b:e])
        
        melody_description = string(m[1:findfirst("\"",m)[1]-1])                
        push!(melody_descriptions,melody_description)
    end
        
    for (m,mstring) in enumerate(melody_strings)
        
        melody = Melody(melody_descriptions[m])

        event_strings = split(mstring,")) ((")
        
        for (e,event_string) in enumerate(event_strings)

            event = Event()
            
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

function parse_data(path)

    # PARSE ALL THE LISP FILES TO A CORPUS

    # NOTE: 21.lisp doesn't parse. is there a missing bracket somewhere? also han0953 has not events. 
    
    filenames = ["$x.lisp" for x in [0:20...,22:25...]]
    filepaths = [joinpath(path,fn) for fn in filenames];
    datasets = [parse_file(fp) for fp in filepaths];
    corpus = Corpus(datasets,"Melch")
    
    return corpus
end

function save_dataset(d::Dataset,fp)

    # SAVE DATASET TO A JLD5 FILE
    
    f = jldopen(fp,"w")

    f["dataset"] = d
    
    close(f)
end

function save_corpus(c::Corpus,fp)

    # SAVE CORPUS TO A JLD5 FILE
    
    f = jldopen(fp,"w")

    f["corpus"] = c
    
    close(f)
end

function load_dataset(fp)

    # LOAD DATASET FROM JLD5 FILE
    
    load(fp)["dataset"]
end

function load_corpus(fp)

    # LOAD CORPUS FROM JLD5 FILE
    
    load(fp)["corpus"]
end

function event_to_df(e::Event)

    # EVENT TO DATAFRAME
    
    return DataFrame(OrderedDict(fieldnames(Event) .=> getfield.(Ref(e), fieldnames(Event))))
end

function melody_to_df(m::Melody)

    # MELODY TO DATAFRAME
    
    return vcat(event_to_df.(m.events)...)
end

function df_to_melody(df::DataFrame,desc)

    # DATAFRAME TO MELODY
    
    melody = Melody(desc)
    for i in 1:size(df)[1]
        event = Event()
        for p in propertynames(df)
            setproperty!(event,p,getproperty(df,p)[i])
        end
        push!(melody.events,event)
    end
    return melody
end

function LOAD(path)

    # LOAD MELCH INTO MEMORY
    
    return parse_data(path)
end

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

####################
# CHAKRA INTERFACE #
####################

Chakra.pts(d::Dataset) = d.melodies
Chakra.pts(m::Melody) = m.events
Chakra.pts(e::Event) = Id[]

Chakra.geta(::Attribute{a,T},d::Dataset) where {a,T} = none
Chakra.geta(::Attribute{a,T},m::Melody) where {a,T} = none
Chakra.geta(::Attribute{a,T},e::Event) where {a,T} = Base.getproperty(e,a)

Chakra.geta(a::Symbol,c::Constituent) = Chakra.geta(Attribute(a),c)

Chakra.fnd(x::DatasetId,c::Corpus) = Base.get(c.datasets,x.dataset,none)
Chakra.fnd(x::MelodyId,c::Corpus) = obind(fnd(id(x.dataset),c), d -> Base.get(d.melodies,x.melody,none))
Chakra.fnd(x::EventId,c::Corpus) = obind(fnd(id(x.dataset,x.melody),c), m -> Base.get(m.events,x.event,none))


end
