ADD_SUBDIRECTORY( hive_fork_manager )

IF ( NOT TARGET hive_protocol )
    ADD_SUBDIRECTORY( protocol )
ENDIF()