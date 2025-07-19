"""Setup configuration for CloudScope."""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="cloudscope",
    version="1.4.0",
    author="CloudScope Team",
    author_email="team@cloudscope.io",
    description="Comprehensive IT Asset Inventory System",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/your-org/cloudscope",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: System Administrators",
        "Topic :: System :: Systems Administration",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
    install_requires=requirements,
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "pytest-asyncio>=0.20.0",
            "black>=23.0.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
            "isort>=5.12.0",
            "pre-commit>=3.0.0",
        ],
        "memgraph": [
            "neo4j>=5.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "cloudscope=src.cli.main:main",
        ],
        "cloudscope.collectors": [
            "csv=src.adapters.collectors.csv_collector:CSVCollector",
        ],
        "cloudscope.exporters": [
            "csv=src.adapters.exporters.csv_exporter:CSVExporter",
            "llm_csv=src.adapters.exporters.csv_exporter:LLMOptimizedCSVExporter",
        ],
    },
    include_package_data=True,
    package_data={
        "cloudscope": [
            "config/*.json",
            "templates/*.html",
            "static/*",
        ],
    },
)
