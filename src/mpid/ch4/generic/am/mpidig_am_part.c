/*
 * Copyright (C) by Argonne National Laboratory
 *     See COPYRIGHT in top-level directory
 */

#include "mpidimpl.h"
#include "mpidch4r.h"
#include "mpidig_am_part_utils.h"

static int part_req_create(void *buf, int partitions, MPI_Aint count,
                           MPI_Datatype datatype, int rank, int tag,
                           MPIR_Comm * comm, MPIR_Request_kind_t kind, MPIR_Request ** req_ptr)
{
    int mpi_errno = MPI_SUCCESS;
    MPIR_Request *req = NULL;

    MPIR_FUNC_VERBOSE_STATE_DECL(MPID_STATE_MPIDIG_PART_REQ_CREATE);
    MPIR_FUNC_VERBOSE_ENTER(MPID_STATE_MPIDIG_PART_REQ_CREATE);

    MPID_THREAD_CS_ENTER(VCI, MPIDI_VCI(0).lock, 0);

    /* Set refcnt=1 for user-defined partitioned pattern; decrease at request_free. */
    req = MPIR_Request_create_from_pool(kind, 0);
    MPIR_ERR_CHKANDSTMT((req) == NULL, mpi_errno, MPIX_ERR_NOREQ, goto fn_fail, "**nomemreq");

    MPIR_Comm_add_ref(comm);
    req->comm = comm;

    MPIR_Datatype_add_ref_if_not_builtin(datatype);
    MPIDI_PART_REQUEST(req, datatype) = datatype;

    MPIDI_PART_REQUEST(req, rank) = rank;
    MPIDI_PART_REQUEST(req, tag) = tag;
    MPIDI_PART_REQUEST(req, buffer) = buf;
    MPIDI_PART_REQUEST(req, count) = count;
    MPIDI_PART_REQUEST(req, context_id) = comm->context_id;

    req->u.part.partitions = partitions;
    MPIR_Part_request_inactivate(req);

    /* Inactive partitioned comm request can be freed by request_free.
     * Completion cntr increases when request becomes active at start. */
    MPIR_cc_set(req->cc_ptr, 0);

    *req_ptr = req;

  fn_exit:
    MPID_THREAD_CS_EXIT(VCI, MPIDI_VCI(0).lock, 0);
    MPIR_FUNC_VERBOSE_EXIT(MPID_STATE_MPIDIG_PART_REQ_CREATE);
    return mpi_errno;
  fn_fail:
    goto fn_exit;
}

static void part_req_am_init(MPIR_Request * part_req)
{
    MPIDIG_PART_REQUEST(part_req, peer_req_ptr) = NULL;
    MPL_atomic_store_int(&MPIDIG_PART_REQUEST(part_req, status), MPIDIG_PART_REQ_UNSET);
}

int MPIDIG_mpi_psend_init(void *buf, int partitions, MPI_Aint count,
                          MPI_Datatype datatype, int dest, int tag,
                          MPIR_Comm * comm, MPIR_Info * info, int is_local, MPIR_Request ** request)
{
    int mpi_errno = MPI_SUCCESS;
    MPIR_FUNC_VERBOSE_STATE_DECL(MPID_STATE_MPIDIG_MPI_PSEND_INIT);
    MPIR_FUNC_VERBOSE_ENTER(MPID_STATE_MPIDIG_MPI_PSEND_INIT);

    MPID_THREAD_CS_ENTER(VCI, MPIDI_VCI(0).lock, 0);

    /* Create and initialize device-layer partitioned request */
    mpi_errno = part_req_create((void *) buf, partitions, count, datatype, dest, tag, comm,
                                MPIR_REQUEST_KIND__PART_SEND, request);
    MPIR_ERR_CHECK(mpi_errno);

    /* Initialize am components for send */
    part_req_am_init(*request);
    MPIR_cc_set(&MPIDIG_PART_REQUEST(*request, u.send).ready_cntr, 0);

    /* Initiate handshake with receiver for message matching */
    MPIDIG_part_send_init_msg_t am_hdr;
    am_hdr.src_rank = comm->rank;
    am_hdr.tag = tag;
    am_hdr.context_id = comm->context_id;
    am_hdr.sreq_ptr = *request;

    MPI_Aint dtype_size = 0;
    MPIR_Datatype_get_size_macro(datatype, dtype_size);
    am_hdr.data_sz = dtype_size * count * partitions;   /* count is per partition */

#ifndef MPIDI_CH4_DIRECT_NETMOD
    MPIDI_REQUEST(*request, is_local) = is_local;       /* use at start, pready, parrived */
    if (is_local)
        mpi_errno = MPIDI_SHM_am_send_hdr(dest, comm, MPIDIG_PART_SEND_INIT,
                                          &am_hdr, sizeof(am_hdr));
    else
#endif
    {
        mpi_errno = MPIDI_NM_am_send_hdr(dest, comm, MPIDIG_PART_SEND_INIT,
                                         &am_hdr, sizeof(am_hdr));
    }

  fn_exit:
    MPID_THREAD_CS_EXIT(VCI, MPIDI_VCI(0).lock, 0);
    MPIR_FUNC_VERBOSE_EXIT(MPID_STATE_MPIDIG_MPI_PSEND_INIT);
    return mpi_errno;
  fn_fail:
    goto fn_exit;
}

int MPIDIG_mpi_precv_init(void *buf, int partitions, int count,
                          MPI_Datatype datatype, int source, int tag,
                          MPIR_Comm * comm, MPIR_Info * info, int is_local, MPIR_Request ** request)
{
    int mpi_errno = MPI_SUCCESS;
    MPIR_FUNC_VERBOSE_STATE_DECL(MPID_STATE_MPIDIG_MPI_PRECV_INIT);
    MPIR_FUNC_VERBOSE_ENTER(MPID_STATE_MPIDIG_MPI_PRECV_INIT);

    /* Create and initialize device-layer partitioned request */
    mpi_errno = part_req_create(buf, partitions, count, datatype, source, tag, comm,
                                MPIR_REQUEST_KIND__PART_RECV, request);
    MPIR_ERR_CHECK(mpi_errno);

    /* Initialize am components for receive */
    part_req_am_init(*request);

    /* Try matching a request or post a new one */
    MPIR_Request *unexp_req = NULL;
    unexp_req = MPIDIG_part_dequeue(source, tag, comm->context_id, &MPIDI_global.part_unexp_list);
    if (unexp_req) {
        /* Copy sender info from unexp_req to local part_rreq */
        MPIDIG_PART_REQUEST(*request, u.recv).sdata_size =
            MPIDIG_PART_REQUEST(unexp_req, u.recv).sdata_size;
        MPIDIG_PART_REQUEST(*request, peer_req_ptr) = MPIDIG_PART_REQUEST(unexp_req, peer_req_ptr);
        MPIR_Request_free_unsafe(unexp_req);

        MPIDIG_part_match_rreq(*request);
        MPIDIG_PART_REQ_INC_FETCH_STATUS(*request);
    } else {
        MPIDIG_part_enqueue(*request, &MPIDI_global.part_posted_list);
    }

#ifndef MPIDI_CH4_DIRECT_NETMOD
    MPIDI_REQUEST(*request, is_local) = is_local;       /* use at start, pready, parrived */
#endif

  fn_exit:
    MPIR_FUNC_VERBOSE_EXIT(MPID_STATE_MPIDIG_MPI_PRECV_INIT);
    return mpi_errno;
  fn_fail:
    goto fn_exit;
}
