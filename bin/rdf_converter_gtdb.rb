#!/usr/bin/env ruby

require 'optparse'
require 'pp'
require 'uri'

#scaffold N50
#http://purl.obolibrary.org/obo/OBI_0001945


module GTDB
  Prefixes = {
    "" => "<http://identifiers.org/gtdb/>",
    "onto" => "<http://identifiers.org/gtdb/onto/>",
    "ddbjtax" => "<http://ddbj.nig.ac.jp/ontologies/taxonomy/>",
    "taxid" => "<http://identifiers.org/taxonomy/>" ,
    "biosample" => "<http://identifiers.org/biosample/>" ,
    "bioproject" => "<http://identifiers.org/bioproject/>" ,
    "gca" => "<http://identifiers.org/insdc.gca/>" ,
    "rdf" => "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>",
    "rdfs" => "<http://www.w3.org/2000/01/rdf-schema#>",
    "skos" => "<http://www.w3.org/2004/02/skos/core#>",
    "obo" => "<http://purl.obolibrary.org/obo/>",
    "dct" => "<http://purl.org/dc/terms/>",
    "xsd" => "<http://www.w3.org/2001/XMLSchema#>",
    "ncbigenome" => "<http://www.ncbi.nlm.nih.gov/datasets/genome/>"
  }

  def prefixes
    Prefixes.each do |pfx, uri|
      print "@prefix #{pfx}: #{uri} .\n"
    end
    puts "\n"
  end

  module_function :prefixes

  @gtdb_taxonomy = {}
  def self.gtdb_taxonomy
    @gtdb_taxonomy
  end

  @hierarchy = {}
  def self.hierarchy
    @hierarchy
  end

  @triples = []
  def self.triples
    @triples
  end

  class Metadata

    def self.rdf(file, prefixes = false)
      File.open(file) do |f|
        header = f.gets.chomp.split("\t").map{|e| e.to_sym}
        GTDB.prefixes if $prefixes
        while line = f.gets
          ary = line.chomp.split("\t")
          construct_turtle(header, ary)
        end
      end
      construct_taxonomy
      put_taxonomy_triples
    end


    def self.construct_turtle(header, ary)
      turtle_str = ""

      if header.size == ary.size
        subj = ":#{ary[0]}"
        print "#{subj}\ta\tddbjtax:Taxon .\n"
        print "#{subj}\tddbjtax:rank\t:Strain .\n"
        print "#{subj}\trdfs:seeAlso\tncbigenome:#{ary[0][3..-1]} .\n"
        print "#{subj}\trdfs:seeAlso\tgca:#{ary[0][3..-1]} .\n"
        (1..header.size - 1).each do |i|
          if header[i] == :gtdb_taxonomy
            if GTDB.gtdb_taxonomy.key?(ary[i])
              GTDB.gtdb_taxonomy[ary[i]] = +1
            else
              GTDB.gtdb_taxonomy[ary[i]] = 1
            end
            parent = "#{ary[i].split(";")[-1].dup.gsub!(" ", "%20")}"
            print "#{subj}\trdfs:subClassOf\t:#{parent} .\n"
            print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
          elsif header[i] == :ncbi_taxid
            print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            print "#{subj}\trdfs:seeAlso\ttaxid:#{ary[i]} .\n"
          elsif header[i] == :ncbi_bioproject
            print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            print "#{subj}\trdfs:seeAlso\tbioproject:#{ary[i]} .\n"
          elsif header[i] == :ncbi_biosample
            print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            print "#{subj}\trdfs:seeAlso\tbiosample:#{ary[i]} .\n"
          elsif header[i] == :ncbi_date
            if /(\d\d\d\d\-\d\d\-\d\d)/ =~ ary[i]
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\"^^xsd:date .\n"
            elsif /(\d\d\d\d)\/(\d\d)\/(\d\d)/ =~ ary[i]
              print "#{subj}\tonto:#{header[i]}\t\"#{$1}-#{$2}-#{$3}\"^^xsd:date .\n"
            else
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            end
          elsif header[i] == :ncbi_seq_rel_date
            if /(\d\d\d\d\-\d\d\-\d\d)/ =~ ary[i]
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\"^^xsd:date .\n"
            elsif /(\d\d\d\d)\/(\d\d)\/(\d\d)/ =~ ary[i]
              print "#{subj}\tonto:#{header[i]}\t\"#{$1}-#{$2}-#{$3}\"^^xsd:date .\n"
            else
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            end
          elsif /^[\d.]+$/ =~ ary[i]
            if ary[i].count('.') > 1
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            else
              print "#{subj}\tonto:#{header[i]}\t#{ary[i]} .\n"
            end
          else
            if ary[i].include?('"')
              print "#{subj}\tonto:#{header[i]}\t\'\'\'#{ary[i]}\'\'\' .\n"
            else
              print "#{subj}\tonto:#{header[i]}\t\"#{ary[i]}\" .\n"
            end
          end
        end
      end
    end

    def self.construct_taxonomy
      GTDB.gtdb_taxonomy.each do |k, v|
        taxons = k.split(";")
        current_rank = GTDB.hierarchy

        taxons.each do |taxon|
          current_rank[taxon] ||= {}
          current_rank = current_rank[taxon]
        end
      end
    end

    def self.add_triples(graph, parent, hierarchy)
      hierarchy.each do |key, value|
        subject = key
        predicate = "rdfs:subClassOf"
        object = parent
        graph << [subject, predicate, object]
    
        add_triples(graph, key, value) unless value.empty?
      end
    end

    def self.put_taxonomy_triples
      root_keys = GTDB.hierarchy.keys
      if root_keys.size == 1 && root_keys[0] == "d__Bacteria"
        print ":d__Bacteria\ta\t:Taxon .\n"
        print ":d__Bacteria\tdct:identifier\t\"d__Bacteria\" .\n"
        print ":d__Bacteria\trdfs:label\t\"d__Bacteria\" .\n"
        print ":d__Bacteria\tskos:altLabel\t\"Bacteria\" .\n"
        print ":d__Bacteria\tddbjtax:rank\t:Domain .\n"
      elsif root_keys.size == 1 && root_keys[0] == "d__Archaea"
        print ":d__Archaea\ta\t:Taxon .\n"
        print ":d__Archaea\tdct:identifier\t\"d__Archaea\" .\n"
        print ":d__Archaea\trdfs:label\t\"d__Archaea\" .\n"
        print ":d__Archaea\tskos:altLabel\t\"Archaea\" .\n"
        print ":d__Archaea\tddbjtax:rank\t:Domain .\n"
      else
        STDERR.print "Error: Unknown root!\n"
      end
      GTDB.hierarchy.each do |root, subtree|
        add_triples(GTDB.triples, root, subtree)
      end
      GTDB.triples.each do |elm|
        e = elm.map{|fe| fe.dup}
        e[0].gsub!(" ", "%20")
        print ":#{e[0]}\t#{e[1]}\t:#{e[2]} .\n"
        print ":#{e[0]}\ta\t:Taxon .\n"
        print ":#{e[0]}\tdct:identifier\t\"#{e[0]}\" .\n"
        print ":#{e[0]}\trdfs:label\t\"#{URI.decode_www_form_component(e[0])}\" .\n"
        print ":#{e[0]}\tskos:altLabel\t\"#{URI.decode_www_form_component(e[0][3..-1])}\" .\n"
        case e[0][0]
        when "d"
          print ":#{e[0]}\tddbjtax:rank\t:Domain .\n"
        when "p"
          print ":#{e[0]}\tddbjtax:rank\t:Phyla .\n"
        when "c"
          print ":#{e[0]}\tddbjtax:rank\t:Class .\n"
        when "o"
          print ":#{e[0]}\tddbjtax:rank\t:Order .\n"
        when "f"
          print ":#{e[0]}\tddbjtax:rank\t:Family .\n"
        when "g"
          print ":#{e[0]}\tddbjtax:rank\t:Genus .\n"
        when "s"
          print ":#{e[0]}\tddbjtax:rank\t:Species .\n"
        else
          STDERR.print "Error: Unknown rank!\n"
        end
      end
    end

        
  end
end

params = ARGV.getopts('hpm:t:', 'help', 'prefixes', 'metadata:', 'tree:')

def help
  print "\nGod helps those who help themselves.:-)\n\n"
end

if params["help"] || params["h"]
  help
  exit
end

$prefixes = true                           if params["prefixes"]
$prefixes = true                           if params["p"]
GTDB::Metadata.rdf(params["metadata"])     if params["metadata"]
GTDB::Metadata.rdf(params["m"])            if params["m"]
GTDB::Tree.rdf(params["metadata"])         if params["tree"]
GTDB::Tree.rdf(params["m"])                if params["t"]

