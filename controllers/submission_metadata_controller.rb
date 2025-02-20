class SubmissionMetadataController < ApplicationController

  ##
  # Display all metadata for submissions
  get '/submission_metadata' do
    reply klass_metadata(LinkedData::Models::OntologySubmission, 'submission_metadata')
  end

  ##
  # Display all metadata for ontologies
  get '/ontology_metadata' do
    reply klass_metadata(LinkedData::Models::Ontology, 'ontology_metadata')
  end
end