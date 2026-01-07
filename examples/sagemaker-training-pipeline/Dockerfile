FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

WORKDIR /opt/ml/code

ENV DATA_DIR=/opt/ml/input/data/training
ENV OUTPUT_DIR=/opt/ml/model
RUN mkdir -p "$DATA_DIR" "$OUTPUT_DIR"

COPY train.py /opt/ml/code/train.py

ENV PYTHONUNBUFFERED=1
ENV SAGEMAKER_PROGRAM=train.py

ENTRYPOINT ["python", "train.py"]