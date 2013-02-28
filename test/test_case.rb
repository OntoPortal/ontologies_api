# Start simplecov if this is a coverage task
if ENV["COVERAGE"].eql?("true")
  require 'simplecov'
  SimpleCov.start do
    add_filter "/test/"
    add_filter "app.rb"
    add_filter "init.rb"
    add_filter "/config/"
  end
end

require_relative '../app'
require 'test/unit'
require 'rack/test'
require 'json'
require 'json-schema'

ENV['RACK_ENV'] = 'test'

# All tests should inherit from this class.
# Use 'rake test' from the command line to run tests.
# See http://www.sinatrarb.com/testing.html for testing information
class TestCase < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
    set :raise_errors, true
    set :dump_errors, false
    set :show_exceptions, false
  end

  def teardown
    if Kernel.const_defined?("TestClsesController") && self.instance_of?(::TestClsesController)
      return
    end
    delete_ontologies_and_submissions
  end

  ##
  # Creates a set of Ontology and OntologySubmission objects and stores them in the triplestore
  # @param [Hash] options the options to create ontologies with
  # @option options [Fixnum] :ont_count Number of ontologies to create
  # @option options [Fixnum] :submission_count How many submissions each ontology should have (acts as max number when random submission count is used)
  # @option options [TrueClass, FalseClass] :random_submission_count Use a random number of submissions between 1 and :submission_count
  # @option options [TrueClass, FalseClass] :process_submission Parse the test ontology file
  def create_ontologies_and_submissions(options = {})
    if Kernel.const_defined?("TestClsesController") && self.instance_of?(::TestClsesController)
      ont = LinkedData::Models::Ontology.find("TST-ONT-0")
      if !ont.nil?
        ont.load unless ont.loaded?
        if ont.submissions.length == 3
          ont.submissions.each do |ss|
            ss.load unless ss.loaded?
            return 1, ["TST-ONT-0"] if ss.submissionStatus.parsed?
          end
        end
      end
    end

    LinkedData::Models::SubmissionStatus.init
    delete_ontologies_and_submissions
    ont_count = options[:ont_count] || 5
    submission_count = options[:submission_count] || 5
    random_submission_count = options[:random_submission_count].nil? ? true : options[:random_submission_count]

    u = LinkedData::Models::User.new(username: "tim", email: "tim@example.org", password: "password")
    u.save unless u.exist? || !u.valid?

    LinkedData::Models::SubmissionStatus.init

    of = LinkedData::Models::OntologyFormat.new(acronym: "OWL")
    if of.exist?
      of = LinkedData::Models::OntologyFormat.find("OWL")
    else
      of.save
    end

    contact_name = "Sheila"
    contact_email = "sheila@example.org"
    contact = LinkedData::Models::Contact.where(name: contact_name, email: contact_email)
    contact = LinkedData::Models::Contact.new(name: contact_name, email: contact_email) if contact.empty?

    ont_acronyms = []
    ontologies = []
    ont_count.to_i.times do |count|
      acronym = "TST-ONT-#{count}"
      ont_acronyms << acronym

      o = LinkedData::Models::Ontology.new({
        acronym: acronym,
        name: "Test Ontology ##{count}",
        administeredBy: u
      })

      o.save
      ontologies << o

      LinkedData::Models::SubmissionStatus.init

      # Random submissions (between 1 and max)
      max = random_submission_count ? (1..submission_count.to_i).to_a.shuffle.first : submission_count
      max.times do
        os = LinkedData::Models::OntologySubmission.new({
          ontology: o,
          hasOntologyLanguage: of,
          submissionStatus: LinkedData::Models::SubmissionStatus.find("UPLOADED"),
          submissionId: o.next_submission_id,
          definitionProperty: (RDF::IRI.new "http://bioontology.org/ontologies/biositemap.owl#definition"),
          summaryOnly: true,
          contact: contact,
          released: DateTime.now - 3
        })
        if (options.include? :process_submission)
          file_path = nil
          if os.submissionId < 4
            file_path = "test/data/ontology_files/BRO_v3.#{os.submissionId-1}.owl"
          else
            raise ArgumentError, "create_ontologies_and_submissions does not support process submission with more than 2 versions"
          end
          uploadFilePath = LinkedData::Models::OntologySubmission.copy_file_repository(o.acronym, os.submissionId, file_path)
          os.uploadFilePath = uploadFilePath
        else
          os.summaryOnly = true
        end
        os.save
      end
    end

    # Get ontology objects if empty
    if ontologies.empty?
      ont_acronyms.each do |ont_id|
        ontologies << LinkedData::Models::Ontology.find(ont_id)
      end
    end

    if options.include? :process_submission
      ontologies.each do |o|
        o.load unless o.loaded?
        o.submissions.each do |ss|
          ss.load unless ss.loaded?
          next if ss.submissionId == 1
          ss.ontology.load unless ss.ontology.loaded?
          ss.process_submission Logger.new(STDOUT)
        end
      end
    end

    return ont_count, ont_acronyms, ontologies
  end

  ##
  # Delete all ontologies and their submissions. This will look for all ontologies starting with TST-ONT- and ending in a Fixnum
  def delete_ontologies_and_submissions
    LinkedData::Models::Ontology.all.each do |ont|
      ont.load unless ont.nil? || ont.loaded?
      ont.submissions.each do |ss|
        ss.load unless ss.loaded?
        ss.delete
      end
      ont.delete
    end

    u = LinkedData::Models::User.find("tim")
    u.delete unless u.nil?

    of = LinkedData::Models::OntologyFormat.find("OWL")
    of.delete unless of.nil?
  end

  # Delete triple store models
  # @param [Array] gooModelArray an array of GOO models
  def delete_goo_models(gooModelArray)
    gooModelArray.each do |m|
      next if m.nil?
      m.load
      m.delete
    end
  end

  # Validate JSON object against a JSON schema.
  # @note schema is only validated after json data fails to validate.
  # @param [String] jsonData a json string that will be parsed by JSON.parse
  # @param [String] jsonSchemaString a json schema string that will be parsed by JSON.parse
  # @param [boolean] list set it true for jsonObj array of items to validate against jsonSchemaString
  def validate_json(jsonData, jsonSchemaString, list=false)
    jsonObj = JSON.parse(jsonData)
    jsonSchema = JSON.parse(jsonSchemaString)
    assert(
        JSON::Validator.validate(jsonSchema, jsonObj, :list => list),
        JSON::Validator.fully_validate(jsonSchema, jsonObj, :validate_schema => true, :list => list).to_s
    )
  end

end
