import json
import os
from pathlib import Path

from test.integration.embedders.utils import validate_embedding_output, validate_raw_embedder
from test.integration.utils import requires_env
from unstructured_ingest.embed.voyageai import VoyageAIEmbeddingConfig, VoyageAIEmbeddingEncoder
from unstructured_ingest.v2.processes.embedder import Embedder, EmbedderConfig

API_KEY = "VOYAGEAI_API_KEY"


def get_api_key() -> str:
    api_key = os.getenv(API_KEY, None)
    assert api_key
    return api_key


@requires_env(API_KEY)
def test_voyageai_embedder(embedder_file: Path):
    api_key = get_api_key()
    embedder_config = EmbedderConfig(embedding_provider="voyageai", embedding_api_key=api_key)
    embedder = Embedder(config=embedder_config)
    results = embedder.run(elements_filepath=embedder_file)
    assert results
    with embedder_file.open("r") as f:
        original_elements = json.load(f)
    validate_embedding_output(original_elements=original_elements, output_elements=results)


@requires_env(API_KEY)
def test_raw_voyageai_embedder(embedder_file: Path):
    api_key = get_api_key()
    embedder = VoyageAIEmbeddingEncoder(
        config=VoyageAIEmbeddingConfig(
            api_key=api_key,
        )
    )
    validate_raw_embedder(
        embedder=embedder, embedder_file=embedder_file, expected_dimensions=(1024,)
    )
