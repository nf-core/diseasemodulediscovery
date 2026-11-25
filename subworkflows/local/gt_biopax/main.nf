
include { BIOPAX_PARSER         } from '../../../modules/local/biopax/parser/main'
include { BIOPAX_VALIDATOR      } from '../../../modules/local/biopax/validator/main'

workflow GT_BIOPAX {

    take:                                   // Workflow inputs
    ch_modules
    idspace
    validate_online

    main:

    BIOPAX_PARSER(ch_modules, idspace, params.add_variants)                        // Parse the biopax files

    if (!params.add_variants){
        BIOPAX_VALIDATOR(BIOPAX_PARSER.out.biopax.collect(), validate_online) // Validate the biopax files
        module = BIOPAX_VALIDATOR.out.validation
    } else {
        module = channel.empty()
    }


    emit:
    module   = module
}
