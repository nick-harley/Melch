module Melch

using DataStructures, DataFrames, JLD2

using Chakra

export id

################
# CONSTITUENTS #
################

mutable struct Event

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

struct Melody

    # TYPE OF MUSICAL MELODIES
    
    events::Vector{Event}
    description::String
end

Melody(desc) = Melody(Event[],desc)

struct Dataset

    # TYPE OF MELODY DATASETS
    
    melodies::Vector{Melody}
    description::String
end

Dataset(desc) = Dataset(Melody[],desc)

###############
# HIERARCHIES #
###############

struct Corpus

    # TYPE OF MELODY CORPORA
    
    datasets::Vector{Dataset}
    description::String
end

Corpus(desc) = Corpus(Dataset[],desc)


###############
# IDENTIFIERS #
###############

abstract type Id end

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
    
    ddesc = s[3:findfirst(".",s)[1]]

    dataset = Dataset(ddesc)

    s = replace(s,"\n " => "","  " => "", ") ("=>")(")[1:end-1]
    
    ms = String[]
    mdescs = String[]
    
    for (i,m) in enumerate(split(s,"(\"")[3:end])
        
        b = findfirst("((",m)[2]+1
        e = findlast("))",m)[1]-2
        push!(ms,m[b:e])
        
        mdesc = string(m[1:findfirst("\"",m)[1]-1])                
        push!(mdescs,mdesc)
    end
        
    for (m,ms) in enumerate(ms)
        
        melody = Melody(mdescs[m])

        event_strings = split(ms,")) ((")
        
        for (e,es) in enumerate(event_strings)

            event = Event()
            
            as = split(es,")(")
                        
            for as in as
                key_val = split(as," ")
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
    
    filenames = ["$x.lisp" for x in 0:25]
    filepaths = [joinpath(path,"data/lisp",fn) for fn in filenames];
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


####################
# CHAKRA INTERFACE #
####################

EVENTATTS = fieldnames(Event)

for EA in EVENTATTS
    Chakra.@Attribute(EA,Int)
end

Chakra.pts(d::Dataset) = d.melodies
Chakra.pts(m::Melody) = m.events
Chakra.pts(e::Event) = Id[]

Chakra.geta(::Att{a,T},d::Dataset) where {a,T} = none
Chakra.geta(::Att{a,T},m::Melody) where {a,T} = none
Chakra.geta(::Att{a,T},e::Event) where {a,T} = a in EVENTATTS ? Base.getproperty(e,a) : none

Chakra.fnd(x::DatasetId,c::Corpus) = Base.get(c.datasets,x.dataset,none)
Chakra.fnd(x::MelodyId,c::Corpus) = obind(fnd(id(x.dataset),c), d -> Base.get(d.melodies,x.melody,none))
Chakra.fnd(x::EventId,c::Corpus) = obind(fnd(id(x.dataset,x.melody),c), m -> Base.get(m.events,x.event,none))


end
