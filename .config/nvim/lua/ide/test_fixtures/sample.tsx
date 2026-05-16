import React from 'react';

interface Props {
  name: string;
  count: number;
}

const Greeting: React.FC<Props> = ({ name, count }) => {
  return (
    <div className="greeting">
      <h1>Hello {name}</h1>
      <p>Count: {count}</p>
    </div>
  );
};

export default Greeting;
